#!/bin/bash

require_here=`readlink -f $(dirname $BASH_SOURCE)`
function require() { source $require_here/$@ ; }
require _utils.sh
 
_assert "root_dir" 'test -d "$root_dir"'
_assert "build_dir" 'test -d "$build_dir"'
_assert "version_xyzw" test -n "$version_xyzw"

function 001_ensure_build_directories() {(
    set -E
    local directories=(
      packages
      CMakeFiles
      copy_win_scripts
      sharedlibs
      llcommon
      newview/CMakeFiles/firestorm-bin.dir
    )

    for x in "${directories[@]}"; do
      test -d $build_dir/$x && echo "[exists] $x" >&2 || mkdir -pv $build_dir/$x
    done
)}

fsversionvalues=(
 CMAKE_BUILD_TYPE=Release
 VIEWER_CHANNEL=$viewer_channel
 VIEWER_VERSION_GITHASH=\"$version_shas\"
 VIEWER_VERSION_MAJOR=$version_major 
 VIEWER_VERSION_MINOR=$version_minor
 VIEWER_VERSION_PATCH=$version_patch
 VIEWER_VERSION_REVISION=$version_release
)

function 002_perform_replacements() {(
    set -E
    echo $version_xyzw | tee $build_dir/newview/viewer_version.txt >&2
    ht-ln $source_dir/newview/icons/development-os/firestorm_icon.ico $build_dir/newview/

    cat $source_dir/newview/fsversionvalues.h.in | sed -E 's~@([A-Z_]+)@~$\1~g' \
      | env ${fsversionvalues[@]} envsubst > $build_dir/newview/fsversionvalues.h

    cat $source_dir/newview/res/viewerRes.rc \
      | env ${fsversionvalues[@]} envsubst > $build_dir/newview/viewerRes.rc

    # TODO: see if there is a way to opt-out via configuration from flickr/discord integration
    ht-ln $source_dir/newview/exoflickrkeys.h.in $build_dir/newview/exoflickrkeys.h
    ht-ln $source_dir/newview/fsdiscordkey.h.in $build_dir/newview/fsdiscordkey.h
)}

function get_msvcdir() {(
  set -E
  _assert "_fsvr_utils_dir" test -f "$_fsvr_utils_dir/generate_msvc_env.bat"
  test -s msvc.env || { $_fsvr_utils_dir/generate_msvc_env.bat > msvc.env ; }
  . msvc.env
  test -n "$VCToolsVersion" || _die "!VCToolsVersion"
  test -d "$VCToolsRedistDir" || _die "!VCToolsRedistDir"
  local TOOLSVER=$(echo $VCToolsVersion | sed -e 's@^\([0-9]\+\)[.]\([0-9]\).*$@\1\2@')
  local CRT=$(cygpath -mas "$VCToolsRedistDir/x64/Microsoft.VC$TOOLSVER.CRT/")
  test -d $CRT || { echo "msvc CRT '$CRT' does not exist" &>2 ; return 1 ; }
  echo "$CRT"
)}

function 003_prepare_msys_msvc() {(
    set -E
    [[ "$OSTYPE" == "msys" ]] || { echo "skipping msys (found OSTYPE='$OSTYPE')" >&2 ; return 0; }

    # make msvcp140.dll redists easy to reference as build/msvc/
    msvc_dir=$(get_msvcdir) || _die "could not get msvc_dir $(ls -l msvc.env)"
    # ht-ln $msvc_dir $build_dir/msvc
    grep msvc_dir $build_dir/build_vars.env >/dev/null \
      || { echo "msvc_dir=$msvc_dir" | tee -a $build_dir/build_vars.env ; }

    # workaround a windows64 ninja viewer_manifest.py path quirkinesses
    ht-ln $build_dir/sharedlibs $build_dir/sharedlibs/Release

  
    if [[ -n "$GITHUB_ACTIONS" ]] ; then
        # TODO: masking the NSIS folder usefully disrupts viewer_manifest.py
        #   past manifest processing and workable firestorm_setup_tmp.nsi emerging
        # see: indra/newview/viewer_manifest.py:    def nsi_file_commands
        test -d C:/PROGRA~2/NSIS && mv -v C:/PROGRA~2/NSIS C:/PROGRA~2/NSIS.old
        # gnu parallel is used to manually download, verify, untar 3p prebuilt dependencies
        which parallel 2>/devnull || { pacman -S parallel --noconfirm --quiet && mkdir -p ~/.parallel/tmp/sshlogin/`hostname` ; echo 65535 > ~/.parallel/tmp/sshlogin/`hostname`/linelen ; }
        # note: autobuild is not necessary here, but viewer_manifest still depends on python-llsd
        python -c 'import llsd' 2>/dev/null || pip install llsd # needed for viewer_manifest.py invocation
    fi
)}

function merge_packages_info() {(
    set -E
    local packages_info=$1
    test -z "$packages_info" && packages_info=/dev/stdin \
    || test -s "$packages_info" || _die "merge_packages_info -- packages-info.json or stdin missing"
    test -s $build_dir/packages-info.json || { echo '{}' > $build_dir/packages-info.json ; }
    local json="$(jq --sort-keys '. + $p' --argjson p "$(jq '.' $packages_info)" $build_dir/packages-info.json)"
    test -n "$json" || _die "problem merging packages infos $packages_info $build_dir/packages-info.json"
    echo "$json" > $build_dir/packages-info.json
    _relativize "merged $packages_info" >&2
)}

function 004_generate_package_infos() {(
    set -E
    cat $_fsvr_utils_dir/../meta/packages-info.json | envsubst | merge_packages_info

    _assert nunja_dir 'test -d "$nunja_dir"'
    merge_packages_info $nunja_dir/packages-info.json

    local openvr_dir=$_fsvr_dir/openvr
    _assert openvr 'test -d "$openvr_dir"'
    #cp -avu $packages_dir/lib/release/openvr_api.dll $build_dir/newview/
    merge_packages_info $openvr_dir/meta/packages-info.json

    # make p373r available to existing llviewerdisplay.cpp
    # (note: -I$build_dir/newview is already part of stock build opts)
    _assert p373r_dir test -d "$p373r_dir"
    _assert p373r_dir 'test -d "$p373r_dir"'
    ht-ln $p373r_dir/llviewerVR.h $build_dir/newview/
    ht-ln $p373r_dir/llviewerVR.cpp $build_dir/newview/
    merge_packages_info $p373r_dir/meta/packages-info.json
)}

function 005_generate_packages_info_text() {(
  set -E
  jq -r '.[]|.name+": "+.version+"\n"+.copyright+"\n"' $build_dir/packages-info.json \
    | tee $build_dir/newview/packages-info.txt
)}

function 006_download_packages() {(
    set -E
    jq -r '.[]|.url' $build_dir/packages-info.json | grep http \
      | parallel --will-cite -j4 'echo {} >&2 && wget -q -P $packages_dir -N {}'
)}

function 007_verify_downloads() {(
    set -E
    echo packages_dir=$packages_dir >&2
    jq -r '.[]|"name="+.name+" hash="+.hash+" url="+(.url//"null")' $build_dir/packages-info.json | grep -v url=null \
     | parallel --will-cite -j4 '{} ; tool=md5sum; test $(echo -n "$hash"|wc -c) == 40 && tool=sha1sum; echo $tool: $(basename $url) ; echo $hash $packages_dir/$(basename $url) | $tool --quiet -c -'
)}

function 008_untar_packages() {(
    set -E
    jq -r '.[]|.url' $build_dir/packages-info.json | grep -vE '^null$' \
       | parallel --will-cite -j4 'basename {} && cd $packages_dir && tar -xf $(basename {})'
)}

function 009_ninja_preflight() {(
    set -E
    _assert nunja_dir 'test -d "$nunja_dir"'
    ( echo "nunja_dir=$nunja_dir" ; cat $build_dir/build_vars.env ; cat $nunja_dir/cl.arrant.nunja ) > $build_dir/build.ninja
    test -f msvc.env && . msvc.env
    ninja -C $build_dir -n
)}

function 00a_ninja_build() {(
  set -E
  test -f msvc.env && . msvc.env
  ninja -C $build_dir -j4 llpackage
)}

function 00b_bundle() {(
  set -E
  . $_fsvr_utils_dir/nsis.sh
  make_installer
  make_7zip
)}

# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "running command: $@" >&2
  eval "$@"
else
  { echo "sourced functions available:" ; declare -f | grep '^0.*()' | sed 's@^@    @g;s@()@@' | sort ; } >&2
fi
