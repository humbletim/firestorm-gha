#!/bin/bash
# minimalist build-cmd.sh replacement for gha autobuilds - humbletim 2022.03.21
set -eu
test -n "$AUTOBUILD" || { echo "only intended for use within AUTOBUILD" ; exit 1 ; }

cd "$(dirname "$0")"

OPENVR_VERSION="v1.6.10"

mkdir -p build stage/lib/release stage/include stage/LICENSES

echo "${OPENVR_VERSION}.${AUTOBUILD_BUILD_ID:=0}" > stage/VERSION.txt

cp -av LICENSE stage/LICENSES/openvr.txt
cp -av headers/openvr.h stage/include

if [[ $AUTOBUILD_PLATFORM == windows64 ]] ; then
  cp -av bin/win64/openvr_api.dll lib/win64/openvr_api.lib stage/lib/release/
fi
if [[ $AUTOBUILD_PLATFORM == linux64 ]] ; then
  cp -av bin/linux64/libopenvr_api.so stage/lib/release/
fi
