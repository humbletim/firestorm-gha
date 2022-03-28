#!/bin/bash
# minimalist build-cmd.sh replacement for gha autobuilds - humbletim 2022.03.21
set -eu
test -n "$AUTOBUILD" || { echo "only intended for use within AUTOBUILD" ; exit 1 ; }

cd "$(dirname "$0")"

mkdir -p stage/lib/release stage/include stage/LICENSES

echo "1.${AUTOBUILD_BUILD_ID:=0}" > stage/VERSION.txt

wdflags=$(echo "
  warning C4334: '<<': result of 32-bit shift implicitly converted to 64 bits
  warning C4244: '=': conversion from 'const double' to 'float', possible loss of data
  warning C4267: 'argument': conversion from 'size_t' to 'const T', possible loss of data
  warning C4996: 'sprintf': This function or variable may be unsafe. Consider using sprintf_s instead.
  warning C4477: 'sprintf' : format string '%lu' requires an argument of type 'unsigned long'
" | awk '{ print $2 }' | sed -e 's@C@-wd@; s@:$@@;')

# hacd="src/hacdGraph.cpp  src/hacdHACD.cpp  src/hacdICHull.cpp  src/hacdManifoldMesh.cpp src/hacdMeshDecimator.cpp src/hacdMicroAllocator.cpp src/hacdRaycastMesh.cpp"
# nd_hacdConvexDecomposition="LLConvexDecomposition.cpp nd_hacdConvexDecomposition.cpp nd_hacdStructs.cpp nd_hacdUtils.cpp nd_EnterExitTracer.cpp nd_StructTracer.cpp"
# nd_Pathing="llpathinglib.cpp llphysicsextensions.cpp"
cxxflags="-D_WINDOWS -DNOMINMAX -D_SECURE_STL=0 -D_HAS_ITERATOR_DEBUGGING=0 -D_SECURE_SCL=0 -W3 -GR -EHsc -MD -O2 -Ob2 -DNDEBUG"

cmake -Wno-dev -S . -G Ninja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE="`echo $cxxflags $wdflags`"
ninja -C build

cp -av build/Source/*/*.lib stage/lib/release/
cp -av ndPhysicsStub.txt stage/LICENSES/
cp -av Source/lib/LLConvexDecomposition.h stage/include/llconvexdecomposition.h
cp -av \
  Source/Pathing/llpathinglib.h \
  Source/Pathing/llphysicsextensions.h \
  Source/lib/ndConvexDecomposition.h \
  "stage/include/"
