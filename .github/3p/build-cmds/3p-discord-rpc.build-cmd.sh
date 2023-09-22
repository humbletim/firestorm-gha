#!/bin/bash
# minimalist build-cmd.sh replacement for gha autobuilds - humbletim 2022.03.21
set -eu
test -n "$AUTOBUILD" || { echo "only intended for use within AUTOBUILD" ; exit 1 ; }

cd "$(dirname "$0")"

DISCORD_SOURCE_DIR="discord-rpc-3.4.0"

# workaround older(?) autobuild runtime issue from Git+Windows MINGW bash prompt
USERPROFILEAppDataLocalMicrosoftWindowsApps=

mkdir -p build
mkdir -p stage/lib/release
mkdir -p stage/LICENSES
mkdir -p stage/include/discord-rpc

wdflags=

if [[ $AUTOBUILD_PLATFORM == windows* ]] ; then
  wdflags=$(echo "
    warning C5039: 'TpSetCallbackCleanupGroup': pointer or reference to potentially throwing function passed to 'extern C' function under -EHc.
    warning C5045: Compiler will insert Spectre mitigation for memory load if /Qspectre switch specified
  " | awk '{ print $2 }' | sed -e 's@C@-wd@; s@:$@@;')
fi

cmake -S $DISCORD_SOURCE_DIR -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_FLAGS="`echo $wdflags`"
ninja -C build

if [[ $AUTOBUILD_PLATFORM == windows* ]] ; then
  cp -av build/src/discord-rpc.{lib,dll} stage/lib/release/
fi

if [[ $AUTOBUILD_PLATFORM == linux* ]] ; then
  cp -av build/src/libdiscord-rpc.so stage/lib/release/
fi

cp -av $DISCORD_SOURCE_DIR/LICENSE stage/LICENSES/discord-rpc.txt
cp -av $DISCORD_SOURCE_DIR/include/*.h stage/include/discord-rpc/
cp -av VERSION.txt stage/
