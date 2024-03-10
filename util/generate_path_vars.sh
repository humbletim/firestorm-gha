#!/bin/bash
set -e
source $(dirname $BASH_SOURCE)/_utils.sh

test -d "$1" || _die "usage: \$ [env workspace=...] generate_path_vars.sh [build_dir]"

root_dir=${workspace:-${root_dir:-${GITHUB_WORKSPACE}}}
build_dir=$1
test -d "$root_dir" || _die "env workspace or GITHUB_WORKSPACE expected as base"
test -d "$build_dir" || _die "build_dir=$build_dir does not exist"

_setenv_extant root_dir=`_realpath $root_dir`
_setenv_extant build_dir=`_realpath $build_dir`
_setenv_extant _fsvr_dir=${_fsvr_dir:-`_realpath $(dirname $BASH_SOURCE)/..`}
_setenv_extant source_dir=${source_dir:-$root_dir/indra}
_setenv packages_dir=${packages_dir:-$build_dir/packages}

test -d "$build_dir" || _usage "build_dir"
test -d "$root_dir" || _usage "root_dir"
#test -e $root_dir/.git || { echo "!$root_dir/.git" ; exit 1; }
test -e $_fsvr_dir/.git || { echo "!$_fsvr_dir/.git" ; exit 1; }
