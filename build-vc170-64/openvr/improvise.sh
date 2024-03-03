#!/bin/bash
set -eu

test -f openvr.tar.gz || curl -L -s https://api.github.com/repos/ValveSoftware/openvr/tarball/v1.6.10 -o openvr.tar.gz
tar --strip-components=1 -xvf openvr.tar.gz ValveSoftware-openvr-8eaf723/lib/win64 ValveSoftware-openvr-8eaf723/bin/win64 ValveSoftware-openvr-8eaf723/headers ValveSoftware-openvr-8eaf723/LICENSE

mkdir -p lib/release include LICENSES
cp -av LICENSE LICENSES/openvr.txt
cp -av headers/openvr.h include
cp -av bin/win64/openvr_api.dll lib/win64/openvr_api.lib lib/release/

tar -cjvf openvr-v1.6.10.8eaf723.tar.bz2 autobuild-package.xml include/openvr.h lib/release/openvr_api.{dll,lib} LICENSES/openvr.txt

tar -tvf openvr-v1.6.10.8eaf723.tar.bz2

