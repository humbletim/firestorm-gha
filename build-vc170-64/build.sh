#!/bin/bash

for x in ogg_vorbis openal apr_suite boost expat xxhash zlib-ng jsoncpp xmlrpc-epi glh_linear glext libpng nghttp2 curl openssl uriparser tut jpeglib openjpeg mes
hoptimizer ndPhysicsStub colladadom minizip-ng pcre libxml2 freetype libhunspell slvoice dictionaries dullahan vlc-bin cubemaptoequirectangular glod jpegencoderba
sic llca libndofdev nvapi threejs gntp-growl discord-rpc ; do
  autobuild install $x --verbose
done

cp -avu /c/PROGRA~1/MICROS~2/2022/ENTERP~1/VC/Redist/MSVC/14.38.33135/x64/Microsoft.VC143.CRT/*{140,140_1}.dll build-vc170-64/msvc/

#ninja -C build-vc170-64 -f relative.vc170.env.ninja -j1 llcommon

