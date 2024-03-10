#!/bin/bash
# generate ninja and bash compatible variable definitions -- humbletim 2024.03.08

_usage="./util/generate_build_vars.sh <viewer channel> <viewer version x.y.z.w> <build dir/>"

viewer_channel=$1 viewer_version=$2 build_dir=$3

set -e

require_here=`readlink -f $(dirname $0)`
function require() { source $require_here/$@ ; }
require _utils.sh

_assert "usage: $_usage"        [[ $# -eq 3 ]]
_assert "invalid channel name" '[[ $viewer_channel =~ ^[-_a-zA-Z0-9.]+$ ]]'
_assert "invalid version"      '[[ $viewer_version =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]'
_assert "invalid build_dir"    'test -d $build_dir'

_setenv viewer_channel=$viewer_channel
require generate_version_vars.sh $viewer_version
require generate_path_vars.sh $build_dir
require generate_git_vars.sh \
  version_git_sha=$root_dir \
  version_fsvr_sha=$_fsvr_dir

version_fsvr_tag=`git tag --contains "$version_fsvr_sha" -n 1`
test -n "$version_fsvr_tag" || version_fsvr_tag=`git branch --contains $version_fsvr_sha --format "%(refname:lstrip=-1)"`

_setenv version_fsvr_tag=$version_fsvr_tag
_setenv version_shas="$version_git_sha-$version_fsvr_sha"
_setenv version_full="$version_xyzw-$version_shas"

_assert "root_dir" 'test -d $root_dir'
