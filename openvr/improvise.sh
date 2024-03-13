#!/bin/bash
set -Euo pipefail

cd "$(dirname $0)"

#test -f openvr.tar.gz || curl -L -s https://api.github.com/repos/ValveSoftware/openvr/tarball/v1.6.10 -o openvr.tar.gz
#tar --strip-components=1 -xvf openvr.tar.gz ValveSoftware-openvr-8eaf723/lib/win64 ValveSoftware-openvr-8eaf723/bin/win64 ValveSoftware-openvr-8eaf723/headers ValveSoftware-openvr-8eaf723/LICENSE
# cp -av LICENSE LICENSES/openvr.txt
# cp -av headers/openvr.h include
# cp -av bin/win64/openvr_api.dll lib/win64/openvr_api.lib lib/release/

# ovr=https://github.com/ValveSoftware/openvr/raw/v1.6.10
# ovr=https://raw.githubusercontent.com/ValveSoftware/openvr/v1.6.10/
ovr=https://rawcdn.githack.com/ValveSoftware/openvr/v1.6.10
tarball=openvr-v1.6.10.8eaf723.tar.bz2
mkdir -p lib/release include LICENSES

set -x

function _wget() { echo "fetching $@" >&2 ; wget -nv -nc "$@" ; }
_wget -O LICENSES/openvr.txt $ovr/LICENSE
_wget -O include/openvr.h $ovr/headers/openvr.h
_wget -P lib/release/ $ovr/bin/win64/openvr_api.dll $ovr/lib/win64/openvr_api.lib
# sha256sum --strict --check openvr.v1.6.10.sha256 || exit 1

test -s include/openvr.h || exit 222
test -s LICENSES/openvr.txt || exit 222

find .

test -f $tarball || tar -cjvf $tarball \
        autobuild-package.xml \
        include/openvr.h \
        lib/release/openvr_api.{dll,lib} \
        LICENSES/openvr.txt

#tar -tvf $tarball

#for x in md5sum sha1sum sha256sum ; do
#  $x $tarball | tee $tarball.$x
#done
