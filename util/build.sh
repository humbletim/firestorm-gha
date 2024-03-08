#!/bin/bash

#. ../build_vars.env

test -d "$root_dir" && test -d "$build_dir" && test -n "$version_string" || { echo "build_vars.env?" >&2 ; exit 1; }

for x in $(echo '
  packages CMakeFiles copy_win_scripts sharedlibs
  llcommon newview/CMakeFiles/firestorm-bin.dir
'); do
    test -d $build_dir/$x || mkdir -pv $build_dir/$x
done

cat $_fsvr_dir/newview/fsversionvalues.h.in | envsubst | tee $build_dir/newview/fsversionvalues.h
test -n "$version_string" || { echo "version_string?" >&2 ; exit 1; }
echo "$version_string" | tee $build_dir/newview/viewer_version.txt

function ht-ln() {
  local target=$1 linkname=$2 opts=""
  test -f $target && test -d $linkname && linkname=$linkname/$(basename $target)
  test -d $target && opts="/J"
  local cmd="mklink $opts $(cygpath -w $linkname) $(cygpath -w $target)"
  echo "[ht-ln] $cmd"
  test -e $linkname && { echo "skipping (exists) $linkname" >&2 ; return 0; }
  MSYS_NO_PATHCONV=1 cmd.exe /C "$cmd"
}

if [[ -n "$GITHUB_ACTIONS" ]] ; then
    function get_msvcdir() {
      test -s msvc.env || { $_fsvr_dir/util/generate_msvc_env.bat > msvc.env ; }
      . msvc.env
      local TOOLSVER=$(echo $VCToolsVersion | sed -e 's@^\([0-9]\+\)[.]\([0-9]\).*$@\1\2@')
      local CRT=$(cygpath -mas "$VCToolsRedistDir/x64/Microsoft.VC$TOOLSVER.CRT/")
      test -d $CRT || { echo "msvc CRT '$CRT' does not exist" &>2 ; return 1 ; }
      echo "$CRT"
    }
    #export -f get_msvcdir
    grep msvc_dir build_vars.env >/dev/null || { echo "msvc_dir=$(get_msvcdir)" | tee -a build_vars.env ; }

    ht-ln $build_dir/sharedlibs $build_dir/sharedlibs/Release
    ht-ln $(get_msvcdir) $build_dir/msvc
    # prevent NSIS from running so we can intercept and add openvr stuff before running manually
    test -d C:/PROGRA~2/NSIS && mv -v C:/PROGRA~2/NSIS C:/PROGRA~2/NSIS.old
    # test -f /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.exe && \
    #   mv -v /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.exe /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.orig.exe
    which parallel || { pacman -S parallel --noconfirm && mkdir -p ~/.parallel/tmp/sshlogin/`hostname` ; echo 65535 > ~/.parallel/tmp/sshlogin/`hostname`/linelen ; }
    python -c 'import llsd' 2>/dev/null || pip install llsd # needed for viewer_manifest.py invocation
fi

# add convencience link so ninja -C build-dir works as shorthand
ht-ln $_fsvr_dir/nunja/cl.arrant.nunja $build_dir/build.ninja

ht-ln $source_dir/newview/icons/development-os/firestorm_icon.ico $build_dir/newview/
ht-ln $source_dir/newview/exoflickrkeys.h.in $build_dir/newview/exoflickrkeys.h
ht-ln $source_dir/newview/fsdiscordkey.h.in $build_dir/newview/fsdiscordkey.h
ht-ln $p373r_dir/llviewerVR.h $build_dir/newview/
ht-ln $p373r_dir/llviewerVR.cpp $build_dir/newview/

export version_comma="${version_string//./,}"
perl -pe '
  s@\$\{VIEWER_VERSION_MAJOR\},\$\{VIEWER_VERSION_MINOR\},\$\{VIEWER_VERSION_PATCH\},\$\{VIEWER_VERSION_REVISION\}@$ENV{version_comma}@g;
  s@\$\{VIEWER_VERSION_MAJOR\}\.\$\{VIEWER_VERSION_MINOR\}\.\$\{VIEWER_VERSION_PATCH\}\.\$\{VIEWER_VERSION_REVISION\}@$ENV{version_string}@g;
' $source_dir/newview/res/viewerRes.rc > $build_dir/newview/viewerRes.rc

test -s $build_dir/packages-info.json || { echo '{}' > $build_dir/packages-info.json ; }
echo "$(jq --sort-keys '. + $p' --argjson p "$(jq '.' $_fsvr_dir/util/packages-info.json)" $build_dir/packages-info.json)" > $build_dir/packages-info.json

function generate_packages_info() {
  jq -r '.[]|.name+": "+.version+"\n"+.copyright+"\n"' $build_dir/packages-info.json \
    | tee $build_dir/newview/packages-info.txt
}
function download_packages() {
    jq -r '.[]|.url' $build_dir/packages-info.json | grep http \
      | parallel --will-cite -j4 'echo {} >&2 && wget -nv -P $packages_dir -N {}'
}
function verify_downloads() {
    jq -r '.[]|"name="+.name+" hash="+.hash+" url="+(.url//"null")' $build_dir/packages-info.json | grep -v url=null \
       | parallel --will-cite -j4 '{} ; echo $hash $packages_dir/$(basename $url) | md5sum --quiet -c - '
}

function untar_packages() {
    jq -r '.[]|.url' $build_dir/packages-info.json | grep -vE '^null$' \
       | parallel --will-cite -j4 'basename {} && cd $packages_dir && tar -xf $(basename {})'
}

