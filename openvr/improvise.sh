#!/bin/bash
set -Euo pipefail

test -d "$fsvr_cache_dir" || { echo "env fsvr_cache_dir not found" >&2 ; exit 15 ; }

# export tag=v2.5.1 commit=ae46a8d
export tag=v1.6.10 commit=8eaf723

tarball=$fsvr_cache_dir/openvr-$tag.$commit.tar.bz2

function verify_from_packages_json() {
  local tarball=$1 json=${2:-$1.json}
  jq --arg tarball "$tarball" -r '.openvr.hash + "\t" + $tarball' $json \
    | tr -d '\r' | tee /dev/stderr | md5sum --strict --check
}

if [[ -s $tarball.json && -s $tarball ]]; then
  if verify_from_packages_json $tarball $tarball.json ; then
    echo "[openvr] $tarball and $tarball.json verified; skipping inline build" >&2
    exit 0
  fi
fi
  
cd "$(dirname $0)"

#test -f openvr.tar.gz || curl -L -s https://api.github.com/repos/ValveSoftware/openvr/tarball/v1.6.10 -o openvr.tar.gz
#tar --force-local --strip-components=1 -xvf openvr.tar.gz ValveSoftware-openvr-8eaf723/lib/win64 ValveSoftware-openvr-8eaf723/bin/win64 ValveSoftware-openvr-8eaf723/headers ValveSoftware-openvr-8eaf723/LICENSE
# cp -av LICENSE LICENSES/openvr.txt
# cp -av headers/openvr.h include
# cp -av bin/win64/openvr_api.dll lib/win64/openvr_api.lib lib/release/

# ovr=https://github.com/ValveSoftware/openvr/raw/v1.6.10
# ovr=https://raw.githubusercontent.com/ValveSoftware/openvr/v1.6.10/

mkdir -pv stage

envsubst < autobuild-package.xml > stage/autobuild-package.xml
touch --reference=autobuild-package.xml stage/autobuild-package.xml
ls -l stage

(
  set -Eou pipefail
  cd stage
  mkdir -pv lib/release include LICENSES

  # openvr repo is hundreds of megabytes... we just need headers, win64 .lib and win64 .dll
  ovr=https://rawcdn.githack.com/ValveSoftware/openvr/$tag
  function _wget() { echo "fetching $@" >&2 ; wget -nv -nc "$@" ; }
  _wget -O LICENSES/openvr.txt $ovr/LICENSE
  _wget -O include/openvr.h $ovr/headers/openvr.h
  _wget -P lib/release/ $ovr/bin/win64/openvr_api.dll $ovr/lib/win64/openvr_api.lib
)

#find stage/ -ls

FILES=(
 autobuild-package.xml
 LICENSES/openvr.txt
 include/openvr.h
 lib/release/openvr_api.{dll,lib}
)

for x in ${FILES[@]} ; do test -s stage/$x || { echo "'$x' invalid" >&2 ; exit 38 ; } ; done || exit 61

#set -x
tar --force-local -C stage -cjvf $tarball ${FILES[@]} || exit 62

hash=($(md5sum $tarball))
url="file:///$tarball"
qualified="$(jq '.openvr.url = $url | .openvr.hash = $hash | .openvr.version = $version' --arg url "$url" --arg hash "$hash" --arg version "$tag.$commit" meta/packages-info.json)"

test ! -s $tarball.json || echo "$qualified" | diff $tarball.json - || true

echo "$qualified" | tee $tarball.json

verify_from_packages_json $tarball $tarball.json \
  || { echo "error verifying provisioned tarball $tarball / $tarball.json" >&2 ; exit 68 ; }

# autobuild installables add openvr url=file:///$fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 \
#     platform=windows64 \
#     hash=`md5sum \
#     $_fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 \
#     | awk '{ print $1 }'`


#tar --force-local -tvf $tarball

#for x in md5sum sha1sum sha256sum ; do
#  $x $tarball | tee $tarball.$x
#done
# sha256sum --strict --check openvr.v1.6.10.sha256 || exit 1
