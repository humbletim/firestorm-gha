#!/bin/bash

function verify_openvr_from_packages_json() {
  local tarball=$1 json=${2:-$1.json}
  jq --arg tarball "$tarball" -r '.openvr.hash + "\t" + $tarball' $json \
    | tr -d '\r' | tee /dev/stderr | md5sum --strict --check
}

function provision_openvr() {(
  set -Euo pipefail
  local cache_dir="$1"
  test -d "$cache_dir" || { echo "env cache_dir('$cache_dir') not found" >&2 ; return 15 ; }

  # export tag=v2.5.1 commit=ae46a8d
  export tag=v1.6.10 commit=8eaf723

  tarball=$cache_dir/openvr-$tag.$commit.tar.bz2

  cd "$(dirname $0)"
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

  FILES=(
   autobuild-package.xml
   LICENSES/openvr.txt
   include/openvr.h
   lib/release/openvr_api.{dll,lib}
  )

  for x in ${FILES[@]} ; do test -s stage/$x || { echo "'$x' invalid" >&2 ; exit 38 ; } ; done || return 61

  #set -x
  tar --force-local -C stage -cjvf $tarball ${FILES[@]} || return 62

  hash=($(md5sum $tarball))
  url="file:///$tarball"
  qualified="$(jq '.openvr.url = $url | .openvr.hash = $hash | .openvr.version = $version' --arg url "$url" --arg hash "$hash" --arg version "$tag.$commit" meta/packages-info.json)"

  test ! -s $tarball.json || echo "$qualified" | diff $tarball.json - || true

  echo "$qualified" | tee $tarball.json

  verify_openvr_from_packages_json $tarball $tarball.json \
    || { echo "error verifying provisioned tarball $tarball / $tarball.json" >&2 ; return 68 ; }

  return 0
)}
