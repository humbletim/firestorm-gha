#!/bin/bash
. build-vc170-64/autobuild.env

FSVRHASH=$(git -C . describe --always --first-parent --abbrev=7)-$(git -C relative describe --always --first-parent --abbrev=7)
perl -i -pe "s@FSVRHASH@${FSVRHASH}@g" build-vc170-64/newview/fsversionvalues.h
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

perl -pe '
  s@\$\{VIEWER_VERSION_MAJOR\},\$\{VIEWER_VERSION_MINOR\},\$\{VIEWER_VERSION_PATCH\},\$\{VIEWER_VERSION_REVISION\}@6,6,17,70368@g;
  s@\$\{VIEWER_VERSION_MAJOR\}\.\$\{VIEWER_VERSION_MINOR\}\.\$\{VIEWER_VERSION_PATCH\}\.\$\{VIEWER_VERSION_REVISION\}@6.6.17.70368@g;
' indra/newview/res/viewerRes.rc > build-vc170-64/newview/viewerRes.rc

# disallow direct NSIS invocations
test -d C:/PROGRA~2/NSIS && mv -v C:/PROGRA~2/NSIS C:/PROGRA~2/NSIS.old

for x in ogg_vorbis openal apr_suite boost expat xxhash zlib-ng jsoncpp xmlrpc-epi glh_linear \
         glext libpng nghttp2 curl openssl uriparser tut jpeglib openjpeg meshoptimizer       \
         ndPhysicsStub colladadom minizip-ng pcre libxml2 freetype libhunspell slvoice        \
         dictionaries dullahan vlc-bin cubemaptoequirectangular glod jpegencoderbasic llca    \
         libndofdev nvapi threejs gntp-growl discord-rpc                                      \
; do
  autobuild install $x --verbose
done

#ninja -C build-vc170-64 -f relative.vc170.env.ninja -j1 llcommon
