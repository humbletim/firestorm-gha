#!/bin/bash

require_here=`readlink -f $(dirname $BASH_SOURCE)`
function require() { source $require_here/$@ ; }
require _utils.sh

require gha.load-level.bash
require gha.upload-artifact.bash
require gha.cachette.bash

_assert "root_dir" 'test -d "$root_dir"'
_assert "build_dir" 'test -d "$build_dir"'
_assert "version_xyzw" test -n "$version_xyzw"
_assert "build_id" test -n "$build_id"

function 010_ensure_build_directories() {( $_dbgopts;
    local directories=(
      packages
      CMakeFiles
      copy_win_scripts
      sharedlibs
      llcommon
      newview/CMakeFiles/${viewer_bin}-bin.dir
    )

    for x in "${directories[@]}"; do
      test -d $build_dir/$x && echo "[exists] $x" >&2 || mkdir -pv $build_dir/$x
    done

    if [[ -x $nunja_dir/010.bash ]] ; then
      echo "[sourcing] $nunja_dir/010.bash" >&2
      . $nunja_dir/010.bash
    fi
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
index 824754c410..738775ba7a 100755
--- a/indra/newview/viewer_manifest.py
+++ b/indra/newview/viewer_manifest.py
@@ -1026,6 +1026,7 @@ class Windows_x86_64_Manifest(ViewerManifest):
                     nsis_path = possible_path
                     break
 
+        return print("[###tpv-gha### early exit]", setattr(self, 'package_file', self.dst_path_of(tempfile)))
         self.run_command([possible_path, '/V2', self.dst_path_of(tempfile)])
 
         self.fs_sign_win_installer(substitution_strings) # <FS:ND/> Sign files, step two. Sign installer.
@@ -2179,6 +2180,7 @@ class LinuxManifest(ViewerManifest):
         # name in the tarfile
         realname = self.get_dst_prefix()
         tempname = self.build_path_of(installer_name)
+        return print("[###tpv-gha### early exit]")
         self.run_command(["mv", realname, tempname])
         try:
             # only create tarball if it's a release build.
EOF
##############################################################################
)

function 020_perform_replacements() {( $_dbgopts;
    echo $version_xyzw | tee $build_dir/newview/viewer_version.txt >&2

    ht-ln $fsvr_dir/newview/cmake_pch.hxx $build_dir/newview/
    ht-ln $fsvr_dir/newview/cmake_pch.cxx $build_dir/newview/

    if [[ $viewer_id == blackdragon ]] ; then
      source $gha_fsvr_dir/bashland/gha.alias-exe.bash
      make-echo-exe "$build_dir/newview/BDVersionChecker.exe" "TODO: newview/BDVersionChecker.exe" || exit 67
      test -x "$build_dir/newview/BDVersionChecker.exe" || exit 68
    fi

    if [[ -f $source_dir/newview/fsversionvalues.h.in ]] ; then
      ht-ln $source_dir/newview/icons/development-os/firestorm_icon.ico $build_dir/newview/
      cat $source_dir/newview/fsversionvalues.h.in | sed -E 's~@([A-Z_]+)@~$\1~g' \
        | eval "${fsversionvalues[@]} envsubst" > $build_dir/newview/fsversionvalues.h || return `_err $? "envsubst fsversionvalues.h.in"`
      grep '###tpv-gha###' $root_dir/indra/newview/viewer_manifest.py || (
        set -ex
        cd $root_dir && echo "$viewer_manifest_patch" | patch -p1
      )
      # TODO: see if there is a way to opt-out via configuration from flickr/discord integration
      ht-ln $source_dir/newview/exoflickrkeys.h.in $build_dir/newview/exoflickrkeys.h
      ht-ln $source_dir/newview/fsdiscordkey.h.in $build_dir/newview/fsdiscordkey.h
    else
      ht-ln $source_dir/newview/icons/test/secondlife.ico $build_dir/newview/
      ht-ln $source_dir/newview/icons/test/secondlife.ico $build_dir/newview/ll_icon.ico
      mkdir -v $packages_dir/js $packages_dir/fonts
      ht-ln $packages_dir/js $source_dir/newview/skins/default/html/common/equirectangular/js
      ht-ln $packages_dir/fonts $source_dir/newview/fonts
    fi

    cat $source_dir/newview/res/viewerRes.rc \
      | eval "${fsversionvalues[@]} envsubst" > $build_dir/newview/viewerRes.rc || return `_err $? "envsubst viewerRes.rc"`
    grep ProductVersion $source_dir/newview/res/viewerRes.rc $build_dir/newview/viewerRes.rc >&2

    # workaround a windows64 ninja viewer_manifest.py path quirkinesses
    ht-ln $build_dir/sharedlibs $build_dir/sharedlibs/Release

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

function 039_provision_p373r() {( $_dbgopts;
    test -d repo/p373r || return 0
    export p373r_dir=$(pwd -W)/repo/p373r
    _assert p373r_dir test -v p373r_dir
    _assert p373r_dir 'test -d "$p373r_dir"'
    cat $p373r_dir/applied >&2 && return 0
    (
      cd $source_dir
      grep P373R newview/llviewerdisplay.cpp >/dev/null || (
        applied=`cat $p373r_dir/applied 2>/dev/null`
        if patch --directory=newview --dry-run --ignore-whitespace --verbose --merge -p1 < $p373r_dir/0001-P373R-6.6.8-baseline-diff.patch > /dev/null ; then
          patch --directory=newview --ignore-whitespace --verbose --merge -p1 < $p373r_dir/0001-P373R-6.6.8-baseline-diff.patch
          applied=0001-P373R-6.6.8-baseline-diff.patch
        fi
        if patch --directory=.. --dry-run --ignore-whitespace --verbose --merge -p1 < $p373r_dir/20240331.diff.U.patch > /dev/null ; then
          patch --directory=.. --ignore-whitespace --verbose --merge -p1 < $p373r_dir/20240331.diff.U.patch
          applied=20240331.diff.U.patch
        fi
        test -n "$applied" || exit 145
        echo "APPLIED: $applied" >&2
      )
    )

    # note: -I$build_dir/newview is already part of stock build opts
    ht-ln $p373r_dir/llviewerVR.h $build_dir/newview/
    ht-ln $p373r_dir/llviewerVR.cpp $build_dir/newview/
)}

function 040_generate_package_infos() {( $_dbgopts;
    _assert $fsvr_dir/meta/packages-info.json 'test -s "$fsvr_dir/meta/packages-info.json"'

    cat $fsvr_dir/meta/packages-info.json | envsubst | merge_packages_info || return `_err $? meta-packages-info`

    merge_packages_info $nunja_dir/packages-info.json || return `_err $? nunja-packages-info`
    test ! -s $fsvr_cache_dir/openvr-*.tar.*.json || \
      merge_packages_info $fsvr_cache_dir/openvr-*.tar.*.json || return `_err $? openvr-packages-info`
    test ! -s repo/p373r/meta/packages-info.json || \
      merge_packages_info repo/p373r/meta/packages-info.json || return `_err $? p373r-packages-info`
)}

function 050_generate_packages_info_text() {( $_dbgopts;
  jq -r '.[]|.name+": "+.version+"\n"+.copyright+"\n"' $build_dir/packages-info.json \
    | tee $build_dir/newview/packages-info.txt
)}


function 090_ninja_preflight() {( $_dbgopts;
    _assert nunja_dir 'test -d "$nunja_dir"'

cat << EOF > $build_dir/build.ninja
include ../env.d/build_vars.env
include ../env.d/gha-bootstrap.env
include msvc.nunja.env
nunja_dir=$nunja_dir
include \$nunja_dir/blueprint.arrant.nunja
EOF

    _assert msvc.env 'test -f $build_dir/msvc.env'
    set -a
    . $build_dir/msvc.env
    . $build_dir/msvc_path.env
    . $BASH_ENV

    echo $msvc_path
    [[ "$OSTYPE" != "msys" ]] || which cl.exe > /dev/null || return 241
    local out="$(ninja -C "$build_dir" -n 2>&1 && echo ninja_preflight_OK | colout -t ninja)"
    echo "$out" | grep ninja_preflight_OK || { echo "$out" ; _die "ninja -n failed" ; }
    echo "$out" | head -3
    echo "..."
    echo "$out" | tail -3
)}

function 0a-1_ninja_fauxbuild() {( $_dbgopts;
    cd $build_dir
    touch llplugin/slplugin/slplugin.exe
    touch media_plugins/libvlc/media_plugin_libvlc.dll
    touch media_plugins/cef/media_plugin_cef.dll
    touch newview/${viewer_bin}-bin.exe
    cat <<EOF>> msvc.nunja.env
cl_exe=true.exe
lib_exe=true.exe
link_exe=true.exe
EOF

)}

function 0a0_ninja_build() {( $_dbgopts;
    _assert msvc.env 'test -f $build_dir/msvc.env'
    set -a
    . $build_dir/msvc.env
    . $build_dir/msvc_path.env
    . $BASH_ENV
    [[ "$OSTYPE" != "msys" ]] || which cl.exe > /dev/null || return 241
    echo "[$FUNCNAME] ninja -C $build_dir ${@:-llpackage}" >&2
    ninja -C "$build_dir" "${@:-llpackage}" | colout -t ninja || _die_exit_code=$? _die "ninja failed"
)}

function 0a1_ninja_postbuild() {( $_dbgopts;
    local nsi=$build_dir/newview/${viewer_bin}_setup_tmp.nsi
    test -f "$nsi" || (
      test -f $(dirname "$nsi")/secondlife_setup_tmp.nsi && \
        ht-ln $(dirname "$nsi")/secondlife_setup_tmp.nsi "$nsi"
    ) || exit $?
    (
      local APPLICATION_EXE=${viewer_name}.exe
      if [[ $viewer_id == blackdragon ]] ; then
        APPLICATION_EXE=SecondLifeViewer.exe
      fi
      APPLICATION_EXE=$(cd $build_dir/newview ; ls $APPLICATION_EXE *Viewer*.exe *-GHA.exe *${viewer_channel}.exe 2>/dev/null | head -n 1)
      _assert APPLICATION_EXE test -f $build_dir/newview/$APPLICATION_EXE
      cat $fsvr_dir/util/load_with_settings_and_cache_here.bat \
        | APPLICATION_EXE=$APPLICATION_EXE envsubst \
        | tee $build_dir/newview/load_with_settings_and_cache_here.bat \
        | grep call
      ls -lrtha $build_dir/newview/load_with_settings_and_cache_here.bat
      test -s $build_dir/newview/load_with_settings_and_cache_here.bat \
        || return `_err $? "err configuring load_with_settings_and_cache_here.bat"`
    ) || exit $?
    test ! -f $packages_dir/lib/release/openvr_api.dll || (
      cp -avu $packages_dir/lib/release/openvr_api.dll $build_dir/newview/
      grep "openvr_api.dll" $nsi \
        || perl -i.bak  -pe 's@^(.*?)\b(OpenAL32.dll)@$1$2\n$1openvr_api.dll@gi' \
         $nsi
      grep "openvr_api.dll" -C2 $nsi
    )
    grep -E ^File "$nsi" | sed -e "s@File [^ ]\+[/\\]newview[/\\]@File @g;s@^File @$viewer_channel-$version_full/@g" | sort -u > $build_dir/installer.txt
    echo "$viewer_channel-$version_full/load_with_settings_and_cache_here.bat" >> $build_dir/installer.txt
    tail -2 $build_dir/installer.txt

    ht-ln $build_dir/newview $build_dir/$viewer_channel-$version_full
)}


function make_installer() {
  local nsi=$build_dir/newview/${viewer_bin}_setup_tmp.nsi
  #s@^SetCompressor .*$@SetCompressor zlib@g;

  export XZ_DEFAULTS=-T0
  (
    cd $build_dir/newview
    PATH=/c/Program\ Files\ \(x86\)/NSIS makensis.exe -V3 $nsi
  )

  local InstallerName=$(basename $build_dir/newview/*Setup*.exe)
  local InstallerExe=${InstallerName/.exe/-$version_shas.exe}
  mv -v $build_dir/newview/*Setup*.exe $build_dir/$InstallerExe
  # echo windows_installer=$build_dir/$InstallerExe | tee -a $GITHUB_OUTPUT
}

function make_7z() {( set -Euo pipefail;
  local nsi=$build_dir/newview/${viewer_bin}_setup_tmp.nsi
  bash -c 'echo $PATH ; which 7z ; cd $build_dir && 7z -bt -t7z a "$build_dir/$viewer_channel-$version_full.7z" "@$build_dir/installer.txt"'
  # echo portable_archive=$build_dir/$viewer_channel-$version_full.7z | tee -a $GITHUB_OUTPUT
)}

function files2json(){
  echo { \"$(< $build_dir/installer.txt sed 's/,/":"/g' | paste -s -d, - | sed 's/,/", "/g')\" } |tr '\\' '/' > files.json
}

function 0b0_bundle_installer() {( $_dbgopts;
  make_installer
)}


function 0b1_upload_installer() {( $_dbgopts;
  local Installer=`ls build/*Setup*.exe |head -1`
  local InstallerName=$(basename $Installer)
  local refid=$(echo "$ref" | sed -e 's@[^-_A-Za-z0-9]@_@g')
  local InstallerExe=$build_id-$refid-${InstallerName}
  mkdir dist
  ht-ln $Installer dist/$InstallerExe

  ( cd dist && gha-upload-artifact ${InstallerExe/.exe/} $InstallerExe )
)}


function 0b2_bundle_7z() {( $_dbgopts;
  make_7z
)}

function 0b3_upload_7z() {( $_dbgopts;
  local Portable=`ls build/${viewer_name}*.7z |head -1`
  local refid=$(echo "$ref" | sed -e 's@[^-_A-Za-z0-9]@_@g')
  local PortableArchive=$build_id-$refid-$(basename $Portable)
  mkdir dist || true
  ht-ln $Portable dist/$PortableArchive

  ( cd dist && gha-upload-artifact ${PortableArchive/.7z/} $PortableArchive )
)}

function 0b4_bundle_zip() {( $_dbgopts;
  # mkdir ziptest
  # tar -C $build_dir -cf - --verbatim-files-from -T $build_dir/installer.txt | tar -C ziptest -xf -
  bash -c 'echo $PATH ; which 7z ; cd $build_dir && 7z -mmt4 -mx9 -bt -tzip a "$build_dir/$viewer_channel-$version_full.zip" "@$build_dir/installer.txt"'
)}

function 0b5_upload_zip() {( $_dbgopts;
  # local refid=$(echo "$ref" | sed -e 's@[^-_A-Za-z0-9]@_@g')
  # local PortableZip=$build_id-$refid-$viewer_channel-$version_full
  # ( cd ziptest && gha-upload-artifact ${PortableZip} . 1 9 )
  local Portable="$build_dir/$viewer_channel-$version_full.zip"
  local refid=$(echo "$ref" | sed -e 's@[^-_A-Za-z0-9]@_@g')
  local PortableArchive=$build_id-$refid-$(basename $Portable)
  mkdir dist || true
  ht-ln $Portable dist/$PortableArchive

  grep gha-patch-upload-artifact /d/a/_actions/actions/upload-artifact/v4/dist/upload/index.js || gha-patch-upload-artifact
  cd dist
  echo zipUploadStream=$PortableArchive gha-upload-artifact-fast ${PortableArchive/.zip/} $build_dir/installer.txt >&2
  zipUploadStream=$PortableArchive gha-upload-artifact-fast ${PortableArchive/.zip/} $build_dir/installer.txt
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
