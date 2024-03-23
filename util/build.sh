#!/bin/bash

require_here=`readlink -f $(dirname $BASH_SOURCE)`
function require() { source $require_here/$@ ; }
require _utils.sh

require gha.load-level.bash
require gha.upload-artifact.bash
require gha.cachette.bash

# echo "root_dir=$root_dir" >&2
_assert "root_dir" 'test -d "$root_dir"'
_assert "build_dir" 'test -d "$build_dir"'
_assert "version_xyzw" test -n "$version_xyzw"

function 010_ensure_build_directories() {( $_dbgopts;
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
 "VIEWER_VERSION_GITHASH=\\\"$version_shas\\\""
 VIEWER_VERSION_MAJOR=$version_major
 VIEWER_VERSION_MINOR=$version_minor
 VIEWER_VERSION_PATCH=$version_patch
 VIEWER_VERSION_REVISION=$version_release
)

##############################################################################
viewer_manifest_patch=$(cat <<'EOF'
diff --git a/indra/newview/viewer_manifest.py b/indra/newview/viewer_manifest.py
index 94636371fc..16577204d7 100755
--- a/indra/newview/viewer_manifest.py
+++ b/indra/newview/viewer_manifest.py
@@ -1009,6 +1009,7 @@ class Windows_x86_64_Manifest(ViewerManifest):
                     nsis_path = possible_path
                     break

+        return print("[###firestorm-gha### early exit]", setattr(self, 'package_file', self.dst_path_of(tempfile)))
         self.run_command([possible_path, '/V2', self.dst_path_of(tempfile)])

         self.fs_sign_win_installer(substitution_strings) # <FS:ND/> Sign files, step two. Sign installer.
EOF
##############################################################################
)

function 020_perform_replacements() {( $_dbgopts;
    echo $version_xyzw | tee $build_dir/newview/viewer_version.txt >&2
    ht-ln $source_dir/newview/icons/development-os/firestorm_icon.ico $build_dir/newview/

    ht-ln $fsvr_dir/newview/cmake_pch.hxx $build_dir/newview/
    ht-ln $fsvr_dir/newview/cmake_pch.cxx $build_dir/newview/

    cat $source_dir/newview/fsversionvalues.h.in | sed -E 's~@([A-Z_]+)@~$\1~g' \
      | eval "${fsversionvalues[@]} C:/PROGRA~1/Git/mingw64/bin/envsubst.exe" > $build_dir/newview/fsversionvalues.h || return `_err $? "envsubst fsversionvalues.h.in"`

    cat $source_dir/newview/res/viewerRes.rc \
      | eval "${fsversionvalues[@]} C:/PROGRA~1/Git/mingw64/bin/envsubst.exe" > $build_dir/newview/viewerRes.rc || return `_err $? "envsubst viewerRes.rc"`

    grep ProductVersion $source_dir/newview/res/viewerRes.rc $build_dir/newview/viewerRes.rc >&2
    # TODO: see if there is a way to opt-out via configuration from flickr/discord integration
    ht-ln $source_dir/newview/exoflickrkeys.h.in $build_dir/newview/exoflickrkeys.h
    ht-ln $source_dir/newview/fsdiscordkey.h.in $build_dir/newview/fsdiscordkey.h

    # workaround a windows64 ninja viewer_manifest.py path quirkinesses
    ht-ln $build_dir/sharedlibs $build_dir/sharedlibs/Release

    grep '###firestorm-gha###' $root_dir/indra/newview/viewer_manifest.py || (
      set -ex
      cd $root_dir && echo "$viewer_manifest_patch" | patch -p1
    )
)}

function 085_prepare_msys_msvc() {( $_dbgopts;
    [[ "$OSTYPE" == "msys" ]] || { echo "skipping msys (found OSTYPE='$OSTYPE')" >&2 ; return 0; }

    if [[ -v GITHUB_ACTIONS ]] ; then
        # TODO: masking the NSIS folder usefully disrupts viewer_manifest.py
        #   past manifest processing and workable firestorm_setup_tmp.nsi emerging
        # see: indra/newview/viewer_manifest.py:    def nsi_file_commands
        test -d C:/PROGRA~2/NSIS && mv -v C:/PROGRA~2/NSIS C:/PROGRA~2/NSIS.old
        # note: autobuild is not necessary here, but viewer_manifest still depends on python-llsd
        python -c 'import llsd' 2>/dev/null || pip install llsd # needed for viewer_manifest.py invocation
    fi
)}

function merge_packages_info() {( $_dbgopts;
    local packages_info=${1:-}
    test -z "$packages_info" && packages_info=- \
    || test -s "$packages_info" || _die "merge_packages_info -- packages-info.json or stdin missing"
    test -s $build_dir/packages-info.json || { echo '{}' > $build_dir/packages-info.json ; }
    local json="$(jq --sort-keys '. + $p' --argjson p "$(jq '.' $packages_info)" $build_dir/packages-info.json)"
    test -n "$json" || _die "problem merging packages infos $packages_info $build_dir/packages-info.json"
    echo "$json" > $build_dir/packages-info.json
    _relativize "merged $packages_info" >&2
)}

function 038_provision_openvr() {( $_dbgopts;
    # _assert openvr_dir test -v openvr_dir
    # _assert openvr_dir 'test -d "$openvr_dir"'
    if ls -l $fsvr_cache_dir/openvr-*.tar.* $fsvr_cache_dir/openvr-*.tar.*.json; then
      echo "using cached openvr" >&2
    else
      bash $fsvr_dir/openvr/improvise.sh || _die "openvr/improvise failed"
      # bash $openvr_dir/install.sh || _die "openvr/install failed"
    fi
    # echo "openvr_tarball_json=\"`cat $fsvr_cache_dir/openvr-*.tar.*.json`\"" | tee -a $GITHUB_OUTPUT
    # mkdir -pv $openvr_dir/meta
    # ht-ln $fsvr_cache_dir/openvr-*.tar.*.json $openvr_dir/meta/packages-info.json
    #cp -avu $packages_dir/lib/release/openvr_api.dll $build_dir/newview/
)}

function 039_provision_p373r() {( $_dbgopts;
    _assert p373r_dir test -v p373r_dir
    _assert p373r_dir 'test -d "$p373r_dir"'
    # apply p373r patch and make llviewerVR.* available to llviewerdisplay.cpp
    bash $p373r_dir/apply.sh || _die "p373r/apply failed"

    # note: -I$build_dir/newview is already part of stock build opts
    ht-ln $p373r_dir/llviewerVR.h $build_dir/newview/
    ht-ln $p373r_dir/llviewerVR.cpp $build_dir/newview/
)}

function 040_generate_package_infos() {( $_dbgopts;
    _assert $fsvr_dir/meta/packages-info.json 'test -s "$fsvr_dir/meta/packages-info.json"'

    cat $fsvr_dir/meta/packages-info.json | envsubst | merge_packages_info || return `_err $? meta-packages-info`

    merge_packages_info $nunja_dir/packages-info.json || return `_err $? nunja-packages-info`
    merge_packages_info $fsvr_cache_dir/openvr-*.tar.*.json || return `_err $? openvr-packages-info`
    merge_packages_info $p373r_dir/meta/packages-info.json || return `_err $? p373r-packages-info`
)}

function 050_generate_packages_info_text() {( $_dbgopts;
  jq -r '.[]|.name+": "+.version+"\n"+.copyright+"\n"' $build_dir/packages-info.json \
    | tee $build_dir/newview/packages-info.txt
)}


function _parallel() {( $_dbgopts;
    local funcname=$1
    shift
    test -f $build_dir/$funcname.txt && rm -v $build_dir/$funcname.txt
    declare -f parallel >/dev/null || return `_err $? "parallel() not defined"`;
    parallel --joblog $build_dir/$funcname.txt --halt-on-error 2 "$@" \
      || { rc=$? ; _relativize "see $build_dir/$funcname.txt" >&2 ; return $rc ; }
)}

function 060_download_packages() {( $_dbgopts;
    _assert fsvr_cache_dir 'test -d "$fsvr_cache_dir"'
    jq -r '.[]|.url' $build_dir/packages-info.json | tr -d '\r' | grep http \
      | _parallel "$FUNCNAME" -j4 'set -e ; echo {} >&2 ; wget -nv -N -P "$fsvr_cache_dir" -N {} ; test -s $fsvr_cache_dir/$(basename {}); exit 0'
)}

function _verify_one() {( $_dbgopts;
    # echo "_verify_one $@"
    local name=$1 hash=$2 filename=$(basename "$3")
    local tool=md5sum
    test $(echo -n "$hash"|wc -c) == 40 && tool=sha1sum
    echo "$hash $filename" > $fsvr_cache_dir/$filename.$tool
    # echo "$tool: $filename ($fsvr_cache_dir)" >&2

    got=($(cd $fsvr_cache_dir && $tool $filename))
    out="$(cd $fsvr_cache_dir && $tool --strict --check $filename.$tool)" || {
        rc=$?
        echo "$out"
        echo "checksum failed: $filename expected: $hash got: $got" >&2 ;
        return $rc
    }
    _relativize "$out"
     #     return 0
)}

function 070_verify_downloads() {( $_dbgopts;
    echo packages_dir=$packages_dir >&2
    echo fsvr_cache_dir=$fsvr_cache_dir >&2
    cd $fsvr_cache_dir/
    test -f $build_dir/$FUNCNAME.txt && rm -v $build_dir/$FUNCNAME.txt
    # echo "`jq -r '.[]|"_verify_one "+.name+" "+.hash+" "+(.url//"null")+""' $build_dir/packages-info.json | grep -v null`"
    jq -r '.[]|"name="+.name+" hash="+.hash+" url="+(.url//"null")' $build_dir/packages-info.json | tr -d '\r' | grep -v url=null \
     | sed -e 's@ url=[^ ]\+/@ url=@' | \
     self=$fsvr_dir/util/build.sh _parallel "$FUNCNAME" -j4 '{} ; $self _verify_one $name $hash $(basename $url)' \
    || _die "verification failed $?"
       # tool=md5sum;
       # test $(echo -n "$hash"|wc -c) == 40 && tool=sha1sum;
       # echo $tool: $(basename $url) ;
       # check="$hash $fsvr_cache_dir/$(basename $url)" ;
       # echo "$check" | $tool --quiet -c -;
    return 0
)}

# function 080_untar_packages() {(
#     $_dbgopts
#     jq -r '.[]|.url' $build_dir/packages-info.json | tr -d '\r' | grep -vE '^null$' \
#      | _parallel "$FUNCNAME" -j8 'basename {} && cd $packages_dir && { bzcat $fsvr_cache_dir/$(basename {}) | 7z -y -ttar -si -bb0 x 2>&1 | { grep -iE "error|warn|fatal|fail" || true ; } ; }' \
#        || _die "untar failed $?"
# )}
#

function 080_untar_packages() {( $_dbgopts;
    jq -r '.[]|.url' $build_dir/packages-info.json | tr -d '\r' | grep -vE '^null$' \
     | _parallel "$FUNCNAME" -j8 'basename {} && cd $packages_dir && tar --force-local -xf $fsvr_cache_dir/$(basename {})' \
       || _die "untar failed $?"
)}

function 090_ninja_preflight() {( $_dbgopts;
    _assert nunja_dir 'test -d "$nunja_dir"'

cat << EOF > $build_dir/build.ninja
include build_vars.env
include msvc.nunja.env
nunja_dir=$nunja_dir
include \$nunja_dir/cl.arrant.nunja
EOF

    _assert msvc.env 'test -f $build_dir/msvc.env'
    set -a
    . $build_dir/msvc.env
    . $build_dir/msvc_path.env
    . $BASH_ENV

    echo $msvc_path
    which cl.exe > /dev/null || return 241
    local out="$(ninja -C "$build_dir" -n 2>&1)" || _die_exit_code=$? _die "ninja -n failed\n$out"
    echo "$out" | head -3
    echo "..."
    echo "$out" | tail -3
)}

function 0a0_ninja_build() {( $_dbgopts;
    _assert msvc.env 'test -f $build_dir/msvc.env'
    set -a
    . $build_dir/msvc.env
    . $build_dir/msvc_path.env
    . $BASH_ENV
    which cl.exe > /dev/null || return 256
    echo "[$FUNCNAME] ninja -C $build_dir ${@:-llpackage}" >&2
    ninja -C "$build_dir" "${@:-llpackage}" || _die_exit_code=$? _die "ninja failed"
)}


function make_installer() {
  cp -avu $packages_dir/lib/release/openvr_api.dll $build_dir/newview/
  local nsi=$build_dir/newview/firestorm_setup_tmp.nsi
  #s@^SetCompressor .*$@SetCompressor zlib@g;
  grep "openvr_api.dll" $nsi \
    || perl -i.bak  -pe 's@^(.*?)\b(growl.dll)@$1$2\n$1openvr_api.dll@g' \
       $nsi

  export XZ_DEFAULTS=-T0
  PATH=/c/Program\ Files\ \(x86\)/NSIS.old makensis.exe -V3 $build_dir/newview/firestorm_setup_tmp.nsi

  local InstallerName=$(basename $build_dir/newview/Phoenix*${viewer_version//./-}*.exe)
  local InstallerExe=${InstallerName/.exe/-$version_shas.exe}
  mv -v $build_dir/newview/Phoenix*${viewer_version//./-}*.exe $build_dir/$InstallerExe
  # echo windows_installer=$build_dir/$InstallerExe | tee -a $GITHUB_OUTPUT
}

function make_7z() {( set -Euo pipefail;
  local nsi=$build_dir/newview/firestorm_setup_tmp.nsi
  grep -E ^File "$nsi" | sed -e "s@.*newview[/\\\\]@$viewer_channel-$version_full/@g" > $build_dir/installer.txt

  echo "-----------------------------------"
  cat $fsvr_dir/util/load_with_settings_and_cache_here.bat;
  echo "-----------------------------------"
  echo APPLICATION_EXE="$(basename `ls $build_dir/newview/Firestorm*.exe`)" envsubst
  echo "-----------------------------------"

  cat $fsvr_dir/util/load_with_settings_and_cache_here.bat \
    | APPLICATION_EXE="$(basename `ls $build_dir/newview/Firestorm*.exe`)" envsubst
  echo "-----------------------------------"


  cat $fsvr_dir/util/load_with_settings_and_cache_here.bat \
   | APPLICATION_EXE="$(basename `ls $build_dir/newview/Firestorm*.exe`)" envsubst \
   | tee $build_dir/newview/load_with_settings_and_cache_here.bat

  ls -lrtha $build_dir/newview/load_with_settings_and_cache_here.bat

  test -s $build_dir/newview/load_with_settings_and_cache_here.bat \
    || return `_err $? "err configuring load_with_settings_and_cache_here.bat"`
  echo "$viewer_channel-$version_full/load_with_settings_and_cache_here.bat" >> $build_dir/installer.txt
  tail -2 $build_dir/installer.txt

  ht-ln $build_dir/newview $build_dir/$viewer_channel-$version_full
  bash -c 'echo $PATH ; which 7z ; cd $build_dir && 7z -bt -t7z a "$build_dir/$viewer_channel-$version_full.7z" "@$build_dir/installer.txt"'
  # echo portable_archive=$build_dir/$viewer_channel-$version_full.7z | tee -a $GITHUB_OUTPUT
)}

function files2json(){
  echo { \"$(< $build_dir/installer.txt sed 's/,/":"/g' | paste -s -d, - | sed 's/,/", "/g')\" } |tr '\\' '/' > files.json
}

function 0b0_bundle() {( $_dbgopts;
  make_installer
  make_7z
)}

function 0c0_upload_artifacts() {( $_dbgopts;
  local Installer=`ls build/Phoenix*.exe |head -1`
  local InstallerName=$(basename $Installer)
  local InstallerExe=$branch-${InstallerName}
  mkdir dist
  ht-ln $Installer dist/$InstallerExe

  ( cd dist && upload-artifact ${InstallerExe/.exe/} $InstallerExe )

  local Portable=`ls build/Firestorm*.7z |head -1`
  local PortableArchive=$branch-$(basename $Portable)
  ht-ln $Portable dist/$PortableArchive

  ( cd dist && upload-artifact ${PortableArchive/.7z/} $PortableArchive )
)}

function _steps() {
    declare -f | grep '^0.*()' | sed 's@^@    @g;s@()@@' | sort
}

# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  $_dbgopts
  cmd=$1
  shift
  if [[ $cmd =~ ^[0-9a-fA-F]{3}$ ]] ; then
    cmd=$(echo $(_steps | grep $cmd))
    echo "cmd=$cmd" >&2
  fi
  test -n "$cmd" || _die "!cmd $cmd $@"
  #echo "running command: $cmd" >&2

  $cmd "$@" || _die "command $cmd '$@' failed $?"
  if [[ ! $cmd =~ ^_ ]]; then
    for x in `_steps 2> /dev/null` ; do
     [[ $x != $cmd && $x > $cmd ]] && echo "    $x"
    done
  fi
  exit 0
else
  { echo "sourced functions available:" ; _steps ; } >&2
fi
