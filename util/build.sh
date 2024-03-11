#!/bin/bash

require_here=`readlink -f $(dirname $BASH_SOURCE)`
function require() { source $require_here/$@ ; }
require _utils.sh
 
_assert "root_dir" 'test -d "$root_dir"'
_assert "build_dir" 'test -d "$build_dir"'
_assert "version_xyzw" test -n "$version_xyzw"

function 010_ensure_build_directories() {(
    _dbgopts
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

function 020_perform_replacements() {(
    _dbgopts

    echo $version_xyzw | tee $build_dir/newview/viewer_version.txt >&2
    ht-ln $source_dir/newview/icons/development-os/firestorm_icon.ico $build_dir/newview/

    ht-ln $_fsvr_dir/newview/cmake_pch.hxx $build_dir/newview/
    ht-ln $_fsvr_dir/newview/cmake_pch.cxx $build_dir/newview/

    cat $source_dir/newview/fsversionvalues.h.in | sed -E 's~@([A-Z_]+)@~$\1~g' \
      | env ${fsversionvalues[@]} envsubst > $build_dir/newview/fsversionvalues.h

    cat $source_dir/newview/res/viewerRes.rc \
      | env ${fsversionvalues[@]} envsubst > $build_dir/newview/viewerRes.rc

    # TODO: see if there is a way to opt-out via configuration from flickr/discord integration
    ht-ln $source_dir/newview/exoflickrkeys.h.in $build_dir/newview/exoflickrkeys.h
    ht-ln $source_dir/newview/fsdiscordkey.h.in $build_dir/newview/fsdiscordkey.h
)}

function get_msvcdir() {(
  _dbgopts
  _assert "_fsvr_utils_dir" test -f "$_fsvr_utils_dir/generate_msvc_env.bat"
  _assert "$build_dir/msvc.env" test -s $build_dir/msvc.env
  . $build_dir/msvc.env
  test -n "$VCToolsVersion" || _die "!VCToolsVersion"
  test -d "$VCToolsRedistDir" || _die "!VCToolsRedistDir"
  local TOOLSVER=$(echo $VCToolsVersion | sed -e 's@^\([0-9]\+\)[.]\([0-9]\).*$@\1\2@')
  local CRT=$(cygpath -mas "$VCToolsRedistDir/x64/Microsoft.VC$TOOLSVER.CRT/")
  test -d $CRT || { echo "msvc CRT '$CRT' does not exist" &>2 ; return 1 ; }
  echo "$CRT"
)}

function 085_prepare_msys_msvc() {(
    _dbgopts
    [[ "$OSTYPE" == "msys" ]] || { echo "skipping msys (found OSTYPE='$OSTYPE')" >&2 ; return 0; }

    if [[ -n "$GITHUB_ACTIONS" ]] ; then
        # TODO: masking the NSIS folder usefully disrupts viewer_manifest.py
        #   past manifest processing and workable firestorm_setup_tmp.nsi emerging
        # see: indra/newview/viewer_manifest.py:    def nsi_file_commands
        test -d C:/PROGRA~2/NSIS && mv -v C:/PROGRA~2/NSIS C:/PROGRA~2/NSIS.old
        # note: autobuild is not necessary here, but viewer_manifest still depends on python-llsd
        python -c 'import llsd' 2>/dev/null || pip install llsd # needed for viewer_manifest.py invocation
    fi

    # workaround a windows64 ninja viewer_manifest.py path quirkinesses
    ht-ln $build_dir/sharedlibs $build_dir/sharedlibs/Release

    # make msvcp140.dll redists easy to reference as build/msvc/
    msvc_dir=$(get_msvcdir) || _die "could not get msvc_dir $(ls -l $build_dir/)"
    # ht-ln $msvc_dir $build_dir/msvc
    grep msvc_dir $build_dir/build_vars.env >/dev/null \
      || { echo "msvc_dir=$msvc_dir" | tee -a $build_dir/build_vars.env ; }  
)}

function merge_packages_info() {(
    _dbgopts
    local packages_info=${1:-}
    test -z "$packages_info" && packages_info=- \
    || test -s "$packages_info" || _die "merge_packages_info -- packages-info.json or stdin missing"
    test -s $build_dir/packages-info.json || { echo '{}' > $build_dir/packages-info.json ; }
    local json="$(jq --sort-keys '. + $p' --argjson p "$(jq '.' $packages_info)" $build_dir/packages-info.json)"
    test -n "$json" || _die "problem merging packages infos $packages_info $build_dir/packages-info.json"
    echo "$json" > $build_dir/packages-info.json
    _relativize "merged $packages_info" >&2
)}

function 040_generate_package_infos() {(
    _dbgopts
    _assert $_fsvr_utils_dir/../meta/packages-info.json 'test -s "$_fsvr_utils_dir/../meta/packages-info.json"'
    cat $_fsvr_utils_dir/../meta/packages-info.json | envsubst | merge_packages_info
   
    _assert nunja_dir 'test -d "$nunja_dir"'
    merge_packages_info $nunja_dir/packages-info.json

    local openvr_dir=$_fsvr_dir/openvr
    _assert openvr 'test -d "$openvr_dir"'
    # set -x
    bash $openvr_dir/improvise.sh || _die "openvr/improvise failed"
    bash $openvr_dir/install.sh || _die "openvr/install failed"
    #cp -avu $packages_dir/lib/release/openvr_api.dll $build_dir/newview/
    merge_packages_info $openvr_dir/meta/packages-info.json

    # apply p373r patch and make llviewerVR.* available to llviewerdisplay.cpp
    # (note: -I$build_dir/newview is already part of stock build opts)
    _assert p373r_dir test -d "$p373r_dir"
    _assert p373r_dir 'test -d "$p373r_dir"'
    bash $p373r_dir/apply.sh || _die "p373r/apply failed"
    ht-ln $p373r_dir/llviewerVR.h $build_dir/newview/
    ht-ln $p373r_dir/llviewerVR.cpp $build_dir/newview/
    merge_packages_info $p373r_dir/meta/packages-info.json
)}

function 050_generate_packages_info_text() {(
  _dbgopts
  jq -r '.[]|.name+": "+.version+"\n"+.copyright+"\n"' $build_dir/packages-info.json \
    | tee $build_dir/newview/packages-info.txt
)}


function _parallel() {(
    _dbgopts
    local funcname=$1
    shift
    test -f $build_dir/$funcname.txt && rm -v $build_dir/$funcname.txt
    parallel --joblog $build_dir/$funcname.txt --halt-on-error 2 "$@" \
      || { rc=$? ; _relativize "see $build_dir/$funcname.txt" >&2 ; return $rc ; }
)}

function 060_download_packages() {(
    _dbgopts
    _assert _fsvr_cache 'test -d "$_fsvr_cache"'
    jq -r '.[]|.url' $build_dir/packages-info.json | tr -d '\r' | grep http \
      | _parallel "$FUNCNAME" -j4 'set -e ; echo {} >&2 ; wget -nv -N -P "$_fsvr_cache" -N {} ; test -s $_fsvr_cache/$(basename {}); exit 0'
)}

function _verify_one() {(
    _dbgopts
    # echo "_verify_one $@"
    local name=$1 hash=$2 filename=$(basename "$3")
    local tool=md5sum
    test $(echo -n "$hash"|wc -c) == 40 && tool=sha1sum
    echo "$hash $filename" > $_fsvr_cache/$filename.$tool 
    # echo "$tool: $filename ($_fsvr_cache)" >&2 
    
    got=($(cd $_fsvr_cache && $tool $filename))
    out="$(cd $_fsvr_cache && $tool --strict --check $filename.$tool)" || {
        rc=$?
        echo "$out"
        echo "checksum failed: $filename expected: $hash got: $got" >&2 ;
        return $rc
    }
    _relativize "$out"
     #     return 0
)}

function 070_verify_downloads() {(
    _dbgopts
    echo packages_dir=$packages_dir >&2
    echo _fsvr_cache=$_fsvr_cache >&2
    cd $_fsvr_cache/
    test -f $build_dir/$FUNCNAME.txt && rm -v $build_dir/$FUNCNAME.txt
    # echo "`jq -r '.[]|"_verify_one "+.name+" "+.hash+" "+(.url//"null")+""' $build_dir/packages-info.json | grep -v null`"
    jq -r '.[]|"name="+.name+" hash="+.hash+" url="+(.url//"null")' $build_dir/packages-info.json | tr -d '\r' | grep -v url=null \
     | sed -e 's@ url=[^ ]\+/@ url=@' | \
     self=$_fsvr_utils_dir/build.sh _parallel "$FUNCNAME" -j4 '{} ; $self _verify_one $name $hash $(basename $url)' \
    || _die "verification failed $?"
       # tool=md5sum;
       # test $(echo -n "$hash"|wc -c) == 40 && tool=sha1sum;
       # echo $tool: $(basename $url) ; 
       # check="$hash $_fsvr_cache/$(basename $url)" ;
       # echo "$check" | $tool --quiet -c -;
    return 0
)}

function 080_untar_packages() {(
    _dbgopts
    jq -r '.[]|.url' $build_dir/packages-info.json | tr -d '\r' | grep -vE '^null$' \
     | _parallel "$FUNCNAME" -j8 'basename {} && cd $packages_dir && { bzcat $_fsvr_cache/$(basename {}) | 7z -y -ttar -si -bb0 x | xargs echo ; }' \
       || _die "untar failed $?"
)}

function 090_ninja_preflight() {(
    _dbgopts
    _assert nunja_dir 'test -d "$nunja_dir"'
    ( 
      echo "include build_vars.env"
      echo "nunja_dir=$nunja_dir" ;
      cat $nunja_dir/cl.arrant.nunja
    ) > $build_dir/build.ninja
    _assert msvc.env 'test -f $build_dir/msvc.env'
    . $build_dir/msvc.env

    local out=
    out="$(ninja -C $build_dir -n 2>&1)" || _die_exit_code=$? _die "ninja -n failed\n$out"
    echo "$out" | head -3
    echo "..."
    echo "$out" | tail -3
)}

function 0a0_ninja_build() {(
    _dbgopts
    _assert msvc.env 'test -f $build_dir/msvc.env'
    . $build_dir/msvc.env
    ninja -C $build_dir -j4 llpackage
)}

function 0b0_bundle() {(
  _dbgopts
  . $_fsvr_utils_dir/nsis.sh
  make_installer
  make_7zip
)}

function _steps() {
    declare -f | grep '^0.*()' | sed 's@^@    @g;s@()@@' | sort 
}

# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _dbgopts
  cmd=$1
  shift
  if [[ $cmd =~ ^[0-9a-fA-F]{3}$ ]] ; then
    cmd=$(_steps | grep $cmd | xargs echo)
    echo "cmd=$cmd" >&2
  fi
  test -n "$cmd" || _die "!cmd $cmd $@"
  #echo "running command: $cmd" >&2
  
  eval "$cmd $@" || _die "command $cmd $@ failed $?"
  if [[ ! $cmd =~ ^_ ]]; then
    for x in `_steps 2> /dev/null` ; do
     [[ $x != $cmd && $x > $cmd ]] && echo "    $x"
    done
  fi
  exit 0  
else
  { echo "sourced functions available:" ; _steps ; } >&2
fi
