#!/bin/bash
set -ae
here=$GITHUB_WORKSPACE
PATH=$here/humbletim-bin:$PATH
AUTOBUILD=`which autobuild`
PYTHON=`which python`
AUTOBUILD_BUILD_ID=-
AUTOBUILD_VARIABLES_FILE=$here/fs-build-variables/variables
AUTOBUILD_ADDRSIZE=64
AUTOBUILD_CONFIG_FILE=$here/autobuild.xml
AUTOBUILD_CONFIGURATION=ReleaseFS_open
AUTOBUILD_INSTALLABLE_CACHE=$here/autobuild-cache

#ogg_vorbis openal apr_suite boost expat xxhash zlib-ng jsoncpp xmlrpc-epi glh_linear glext libpng nghttp2 curl openssl uriparser tut jpeglib openjpeg meshoptimizer ndPhysicsStub colladadom minizip-ng pcre libxml2 freetype libhunspell slvoice dictionaries dullahan vlc-bin cubemaptoequirectangular glod jpegencoderbasic llca libndofdev nvapi threejs gntp-growl discord-rpc ; do

#$AUTOBUILD configure -A 64 -c ReleaseFS_open -- --ninja --openal --package
