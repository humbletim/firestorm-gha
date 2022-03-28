#!/bin/bash
# minimalist build-cmd.sh replacement for gha autobuilds - humbletim 2022.03.21
set -eu
test -n "$AUTOBUILD" || { echo "only intended for use within AUTOBUILD" ; exit 1 ; }

. $_3P_UTILSDIR/_dsp_sourcefiles.sh

cd "$(dirname "$0")"

mkdir -p stage/include/glod
mkdir -p stage/LICENSES
mkdir -p stage/lib/release

GLOD_VERSION=$(grep -E '^GLOD [0-9]' README | head -1 | awk '{ print $2 }')
echo "${GLOD_VERSION}.${AUTOBUILD_BUILD_ID:=0}" > stage/VERSION.txt

DSPFILES="
  src/api/glodlib.dsp
  src/mt/mt.dsp
  src/ply/ply.dsp
  src/vds/vdslib_glod.dsp
  src/xbs/xbs.dsp
"
SRCS=$(
  for dsp in $DSPFILES ; do
    _dsp_sourcefiles "$dsp" -Tp
  done
)
echo SRCS=$SRCS >&2

# tidy up some warnings
wdflags=$(echo "
  warning C4838: conversion from '__int64' to 'int' requires a narrowing conversion
  warning C4477: 'fprintf' : format string '%x' requires an argument of type 'unsigned int'
  warning C4313: 'fprintf': '%x' in format string conflicts with argument 1 of type 'Tri *'
" | awk '{ print $2 }' | sed -e 's@C@-wd@; s@:$@@;')

cl -O2 -DNDEBUG -EHsc -DGLOD -D_MBCS -DGLOD_EXPORTS -Iinclude -Isrc/include -Isrc/mt -Isrc/xbs -Isrc/vds $wdflags $SRCS -LD -Feglod.dll

cp -av glod.{lib,dll} stage/lib/release/
cp -av include/glod.h stage/include/glod/
cp -av LICENSE stage/LICENSES/GLOD.txt
