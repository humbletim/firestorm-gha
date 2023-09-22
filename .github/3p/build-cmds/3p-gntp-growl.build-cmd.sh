#!/bin/bash
# minimalist build-cmd.sh replacement for gha autobuilds - humbletim 2022.03.21
set -eu
test -n "$AUTOBUILD" || { echo "only intended for use within AUTOBUILD" ; exit 1 ; }

cd "$(dirname "$0")"

mkdir -p stage/lib/release stage/lib/debug
mkdir -p stage/include/Growl
mkdir -p stage/LICENSES
echo "1.0" > stage/VERSION.txt

cmake -S gntp-send -G Ninja -B build -DCMAKE_BUILD_TYPE=Release
ninja -C build growl growl++

cp -av build/*.{dll,lib} stage/lib/release/
cp -av build/*.{dll,lib} stage/lib/debug/
cp -av gntp-send/headers/{growl++.hpp,growl.h} stage/include/Growl/
cp -av gntp-send/LICENSE stage/LICENSES/gntp-growl.txt

