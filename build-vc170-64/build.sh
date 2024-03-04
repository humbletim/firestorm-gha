#!/bin/bash

#. ../build_vars.env

test -d "$root_dir" && test -d "$build_dir" && test -n "$version_string" || { echo "build_vars.env?" ; exit 1; }

cat build-vc170-64/newview/fsversionvalues.h.in | envsubst | tee build-vc170-64/newview/fsversionvalues.h

mkdir -p build-vc170-64/msvc/
mkdir -p build-vc170-64/CMakeFiles/
mkdir -p build-vc170-64/copy_win_scripts/
mkdir -p build-vc170-64/sharedlibs/

if [[ -n "$GITHUB_ACTIONS" ]] ; then
    MSYS_NO_PATHCONV=1 cmd.exe /C 'cd build-vc170-64\sharedlibs && mklink /D Release .'
    cp -avu /c/PROGRA~1/MICROS~2/2022/ENTERP~1/VC/Redist/MSVC/14.38.33135/x64/Microsoft.VC143.CRT/*{140,140_1}.dll $build_dir/msvc/
    test -d C:/PROGRA~2/NSIS && mv -v C:/PROGRA~2/NSIS C:/PROGRA~2/NSIS.old
    test -f /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.exe && \
      mv -v /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.exe /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.orig.exe
    pacman -S parallel --noconfirm
    echo 65535 > ~/.parallel/tmp/sshlogin/`hostname`/linelen

fi

test -f $build_dir/build.ninja || sh -c 'cd build-vc170-64 && ln -s relative.vc170.env.ninja build.ninja'

cp -avu $source_dir/newview/icons/development-os/firestorm_icon.ico $build_dir/newview/
cp -avu $source_dir/newview/exoflickrkeys.h.in $build_dir/newview/exoflickrkeys.h
cp -avu $source_dir/newview/fsdiscordkey.h.in $build_dir/newview/fsdiscordkey.h

export version_comma="${version_string//./,}"
perl -pe '
  s@\$\{VIEWER_VERSION_MAJOR\},\$\{VIEWER_VERSION_MINOR\},\$\{VIEWER_VERSION_PATCH\},\$\{VIEWER_VERSION_REVISION\}@$ENV{version_comma}@g;
  s@\$\{VIEWER_VERSION_MAJOR\}\.\$\{VIEWER_VERSION_MINOR\}\.\$\{VIEWER_VERSION_PATCH\}\.\$\{VIEWER_VERSION_REVISION\}@$ENV{version_string}@g;
' $source_dir/newview/res/viewerRes.rc > $build_dir/newview/viewerRes.rc

# for x in `cat $build_dir/packages.txt` ; do
#    jq -r --arg x "$x" '.[$x]|$x+": "+.version+"\n"+.copyright+"\n"' $build_dir/packages-info.json
# done | tee $build_dir/newview/packages-info.txt

jq -r '.[]|.name+": "+.version+"\n"+.copyright+"\n"' $build_dir/packages-info.json | tee $build_dir/newview/packages-info.txt

# jq -r '.[]|.url' ../build-vc170-64/packages-info.json |fgrep http | parallel --will-cite -j4 wget -nv -N {}



# disallow direct NSIS invocations
