#!/bin/bash
# minimalist build-cmd.sh replacement for gha autobuilds - humbletim 2022.03.21
set -eu
test -n "$AUTOBUILD" || { echo "only intended for use within AUTOBUILD" ; exit 1 ; }

cd "$(dirname "$0")"

OPENJPEG_VERSION="2.4.0"

mkdir -p build stage/lib/release stage/lib/debug stage/include/openjpeg stage/LICENSES

echo "${OPENJPEG_VERSION}.${AUTOBUILD_BUILD_ID:=0}" > stage/VERSION.txt

wdflags=
if [[ $AUTOBUILD_PLATFORM == windows* ]] ; then
  wdflags=$(echo "
    warning C4267: '=': conversion from 'size_t' to 'OPJ_UINT32', possible loss of data
  " | awk '{ print $2 }' | sed -e 's@C@/wd@; s@:$@@;')
fi

cmake -Wno-dev -S src -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=" `echo $wdflags`"
ninja -C build openjp2

cp -av build/LICENSE.txt stage/LICENSES/openjpeg.txt
cp -av src/src/lib/openjp2/{openjpeg.h,opj_stdint.h,event.h} stage/include/openjpeg/
cp -av build/src/lib/openjp2/opj_config.h stage/include/openjpeg/
if [[ $AUTOBUILD_PLATFORM == windows* ]] ; then
  cp -av build/bin/openjp2{.dll,.lib} stage/lib/release/
  cp -av build/bin/openjp2{.dll,.lib} stage/lib/debug/
fi
if [[ $AUTOBUILD_PLATFORM == linux* ]] ; then
  cp -avL build/bin/libopenjp2.so stage/lib/release/
  cp -avL build/bin/libopenjp2.so stage/lib/debug/
fi

