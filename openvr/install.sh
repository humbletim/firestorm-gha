#!/bin/bash
test -d "$build_dir" || { echo "!build_dir" >&2 ; exit 1; }
test -d "$_fsvr_dir" || { echo "!_fsvr_dir" >&2 ; exit 1; }
set -xe
tarball=$_fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2
hash=($(md5sum $tarball))
url="file:///$tarball"
qualified="$(jq '.openvr.url = $url | .openvr.hash = $hash' --arg url "$url" --arg hash "$hash" $_fsvr_dir/openvr/meta/packages-info.json)"

test -s $build_dir/packages-info.json || { echo '{}' > $build_dir/packages-info.json ; }

fgrep openvr $build_dir/packages-info.json || { echo "$(jq --sort-keys '. + $p' --argjson p "$qualified" $build_dir/packages-info.json)" > $build_dir/packages-info.json ; }

jq .openvr $build_dir/packages-info.json

cp -av $tarball $packages_dir

# autobuild installables add openvr url=file:///$_fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 \
#     platform=windows64 \
#     hash=`md5sum \
#     $_fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 \
#     | awk '{ print $1 }'`
