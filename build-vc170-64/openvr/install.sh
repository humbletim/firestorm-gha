#!/bin/bash
. $GITHUB_WORKSPACE/build-vc170-64/autobuild.env

set -xe
autobuild installables add openvr url=file:///$(cygpath -m "$GITHUB_WORKSPACE")/build-vc170-64/openvr/openvr-v1.6.10.8eaf723.tar.bz2 platform=windows64 hash=`md5sum build-vc170-64/openvr/openvr-v1.6.10.8eaf723.tar.bz2|awk '{ print $1 }'` 




