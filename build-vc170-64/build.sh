#!/bin/bash

#. ../build_vars.env

test -d "$root_dir" && test -d "$build_dir" && test -n "$version_string" || { echo "build_vars.env?" ; exit 1; }

perl -i -pe "s@FSVRHASH@${version_sha}@g" build-vc170-64/newview/fsversionvalues.h
cat build-vc170-64/newview/fsversionvalues.h

mkdir -p build-vc170-64/msvc/
mkdir -p build-vc170-64/CMakeFiles/
mkdir -p build-vc170-64/copy_win_scripts/
mkdir -p build-vc170-64/sharedlibs/
MSYS_NO_PATHCONV=1 cmd.exe /C 'cd build-vc170-64\sharedlibs && mklink /D Release .'

sh -c 'cd build-vc170-64 && ln -s relative.vc170.env.ninja build.ninja'

cp -avu indra/newview/icons/development-os/firestorm_icon.ico build-vc170-64/newview/
cp -avu /c/PROGRA~1/MICROS~2/2022/ENTERP~1/VC/Redist/MSVC/14.38.33135/x64/Microsoft.VC143.CRT/*{140,140_1}.dll build-vc170-64/msvc/
cp -avu indra/newview/exoflickrkeys.h.in build-vc170-64/newview/exoflickrkeys.h
cp -avu indra/newview/fsdiscordkey.h.in build-vc170-64/newview/fsdiscordkey.h

export version_comma="${version_string//./,}"
perl -pe '
  s@\$\{VIEWER_VERSION_MAJOR\},\$\{VIEWER_VERSION_MINOR\},\$\{VIEWER_VERSION_PATCH\},\$\{VIEWER_VERSION_REVISION\}@$ENV{version_comma}@g;
  s@\$\{VIEWER_VERSION_MAJOR\}\.\$\{VIEWER_VERSION_MINOR\}\.\$\{VIEWER_VERSION_PATCH\}\.\$\{VIEWER_VERSION_REVISION\}@$ENV{version_string}@g;
' indra/newview/res/viewerRes.rc > build-vc170-64/newview/viewerRes.rc

# disallow direct NSIS invocations
test -d C:/PROGRA~2/NSIS && mv -v C:/PROGRA~2/NSIS C:/PROGRA~2/NSIS.old

test -f /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.exe && \
  mv -v /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.exe /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts/autobuild.orig.exe

# for x in `ls autobuild-cache/` ; do echo $x | perl -pe 's@^(\w+)-(.*?)-(windows|common).*$@\1: \2@g' ; done

autobuild.orig.exe print --json > autobuild.orig.json
jq '
  [.installables[]| . as $root | (.platforms//{}|(.windows64//.common//.windows//{archive:{}}).archive) as $archive | $root | {key:.name,value:{
     name:.name,
     copyright: (.copyright // "") | sub("[[::space::]]+$"; ""),
     version: (.version // ($archive.url | capture(".*/(?<prefix>\\w+)-(?<version>[-.a-zA-Z0-9_]+)-(common|windows)"; "n")//{}).version),
     url: $archive.url, hash: $archive.hash
  }}]|from_entries
' autobuild.orig.json |tee _autobuild.json

#exit
# autobuild print --json | jq '.installables[].platforms|.windows64//.common//.windows|.archive.url' -r > autobuild.urls

packages="openvr ogg_vorbis openal apr_suite boost expat xxhash zlib-ng jsoncpp xmlrpc-epi glh_linear \
         glext libpng nghttp2 curl openssl uriparser tut jpeglib openjpeg meshoptimizer       \
         ndPhysicsStub colladadom minizip-ng pcre libxml2 freetype libhunspell slvoice        \
         dictionaries dullahan vlc-bin cubemaptoequirectangular glod jpegencoderbasic llca    \
         libndofdev nvapi threejs gntp-growl discord-rpc"

for x in `echo $packages` ; do
   jq -r --arg x "$x" '.[$x]|$x+": "+.version+"\n"+.copyright+"\n"' _autobuild.json
done > build-vc170-64/newview/packages-info.txt

#ninja -C build-vc170-64 -f relative.vc170.env.ninja -j1 llcommon

for x in `echo $packages` ; do
   jq -r --arg x "$x" '.[$x].url' _autobuild.json
done
