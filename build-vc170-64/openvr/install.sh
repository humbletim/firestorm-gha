#!/bin/bash
test -d "$build_dir" && test -f "$AUTOBUILD_CONFIG_FILE"
set -xe

hash=($(md5sum $build_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2))
url="file:///$build_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2"
echo $(jq '.openvr.url = $url | .openvr.hash = $hash' --arg url "$url" --arg hash "$hash" $build_dir/packages-info.json) > $build_dir/packages-info.json
jq .openvr $build_dir/packages-info.json

# autobuild installables add openvr url=file:///$build_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 \
#     platform=windows64 \
#     hash=`md5sum \
#     $build_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 \
#     | awk '{ print $1 }'`
