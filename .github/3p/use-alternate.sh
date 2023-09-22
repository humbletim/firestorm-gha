#!/bin/bash
# github actions helper that patches autobuild.xml to use an alternate source
# -- humbletim 2022.03.27

# note: autobuild props are derived from the url's tar.bz2 filename
# usage:
#    .github/3p/use-alternate.sh <url> <md5sum>
# or .github/3p/use-alternate.sh "<url>=<md5sum>"

set -eu
. .github/3p/_assert_defined.sh
. .github/3p/_autobuild_prop_as_json.sh

assert_defined AUTOBUILD_CONFIG_FILE AUTOBUILD_PLATFORM

autobuild_package_filename=${1%=*}
autobuild_package_md5=${1#*=}
if [[ -z $autobuild_package_md5 ]] ; then
  autobuild_package_md5=${2}
fi

# extract <name>-<version>-<platform>-<id>.tar.bz2
filename=$(basename $autobuild_package_filename)
regex='^([-a-z][a-z0-9]+)-([.0-9]+)-(common|windows|windows64|darwin|darwin64|linux|linux64)-(.*)(\.tar\.(bz2|gz|xz)|\.zip)$'
if [[ $filename =~ $regex ]] ; then
  autobuild_package_name=${BASH_REMATCH[1]}
  autobuild_package_version=${BASH_REMATCH[2]}
  autobuild_package_platform=${BASH_REMATCH[3]}
  autobuild_package_id=${BASH_REMATCH[4]}
fi

assert_defined autobuild_package_name autobuild_package_filename autobuild_package_md5

# snapshot autobuild.xml before/after state to detect modifications
before=$(autobuild_prop_as_json $autobuild_package_name .archive)

autobuild installables edit $autobuild_package_name hash=$autobuild_package_md5 url=$autobuild_package_filename

after=$(autobuild_prop_as_json $autobuild_package_name .archive)
if [[ "$before" != "$after" ]] ; then
  echo "UPDATED autobuild.xml: $after"
fi
