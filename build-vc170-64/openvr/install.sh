#!/bin/bash
test -d "$build_dir" && test -f "$AUTOBUILD_CONFIG_FILE"
set -xe
autobuild installables add openvr url=file:///$build_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2 platform=windows64 hash=`md5sum $build_dir/openvr/openvr-v1.6.10.8eaf723.tar.bz2|awk '{ print $1 }'`
