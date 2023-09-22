#!/bin/bash
# minimalist build-cmd.sh replacement for gha autobuilds - humbletim 2022.03.21
set -eu
test -n "$AUTOBUILD" || { echo "only intended for use within AUTOBUILD" ; exit 1 ; }

. $_3P_UTILSDIR/_dsp_sourcefiles.sh

cd "$(dirname "$0")"

FREETYPELIB_SOURCE_DIR="freetype-2.3.9"
FREETYPE_VERSION=${FREETYPELIB_SOURCE_DIR#*-}

top="$(pwd)"
stage="$(pwd)/stage"
mkdir -p $stage/lib/release
mkdir -p $stage/include/freetype2/
mkdir -p $stage/LICENSES
mkdir -p $stage/docs/freetype

if [[ $AUTOBUILD_PLATFORM == linux* ]] ; then
  function cl() {
    $CXX -fPIC "$@"
  }
  function lib() {
    local args="${@/-out:/-shared -o }"
    args="${args/freetype.lib/libfreetype.so}"
    args="${args/.obj/.o}"
    ld ${args}
  }
fi
pushd $FREETYPELIB_SOURCE_DIR
  SRCS=$(_dsp_sourcefiles builds/win32/visualc/freetype.dsp)

  wdflags=
  if [[ $AUTOBUILD_PLATFORM == windows* ]] ; then
    # tidy up some warnings
    wdflags=$(echo "
      warning C4312: 'type cast': conversion from 'unsigned long' to 'void *' of greater size
      warning C4311: 'type cast': pointer truncation from 'void *' to 'unsigned long'
    " | awk '{ print $2 }' | sed -e 's@C@-wd@; s@:$@@;')
  fi

  set -x
    # -I$stage/packages/include/zlib-ng
    cl -O2 -Iinclude -DNDEBUG -DFT2_BUILD_LIBRARY -D_MBCS -D_LIB -c $SRCS $wdflags
    lib *.obj -out:$stage/lib/release/freetype.lib
  set +x

  cp -av include/ft2build.h $stage/include/
  cp -av include/freetype $stage/include/freetype2/
  cp -av docs/LICENSE.TXT $stage/LICENSES/freetype.txt
popd

cp -av README.Linden $stage/docs/freetype/
echo "${FREETYPE_VERSION}.${AUTOBUILD_BUILD_ID}" | tee ${stage}/VERSION.txt
