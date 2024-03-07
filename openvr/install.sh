#!/bin/bash
test -d "$_fsvr_dir" || { echo "!_fsvr_dir" >&2 ; exit 1; }
set -xe

hash=($(md5sum $_fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2))
url="file:///$_fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2"
qualified="$(jq '.openvr.url = $url | .openvr.hash = $hash' --arg url "$url" --arg hash "$hash" $_fsvr_dir/openvr/meta/packages-info.json)"

echo "$(jq --sort-keys '. + $p' --argjson p "$qualified" $build_dir/packages-info.json)" > $build_dir/packages-info.json

jq .openvr $build_dir/packages-info.json

# autobuild installables add openvr url=file:///$_fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 \
#     platform=windows64 \
#     hash=`md5sum \
#     $_fsvr_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 \
#     | awk '{ print $1 }'`
