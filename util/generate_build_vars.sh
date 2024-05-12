#!/bin/bash
# generate ninja and bash compatible variable definitions -- humbletim 2024.03.08
set -Euo pipefail
viewer_channel=$1 viewer_version=$2 build_dir=$3

source $gha_fsvr_dir/util/_utils.sh

_assert "invalid channel name" '[[ $viewer_channel =~ ^[-_a-zA-Z0-9.]+$ ]]'
_assert "invalid version"      '[[ $viewer_version =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]'
_assert "invalid build_dir"    'test -d $build_dir'

_setenv viewer_channel=$viewer_channel

function _ver_split() { echo "$1" | cut -d "." -f $2 ; }
_setenv viewer_version=$viewer_version
_setenv version_major=`  _ver_split $viewer_version 1`
_setenv version_minor=`  _ver_split $viewer_version 2`
_setenv version_patch=`  _ver_split $viewer_version 3`
_setenv version_release=`_ver_split $viewer_version 4`
_setenv version_xyz=$version_major.$version_minor.$version_patch
_setenv version_xyzw=$version_xyz.$version_release
_setenv slos_version=$viewer_version


_setenv_extant root_dir=`_realpath $root_dir`
_setenv_extant build_dir=`_realpath $build_dir`
_setenv_extant source_dir=${source_dir:-$root_dir/indra}
_setenv packages_dir=${packages_dir:-$build_dir/packages}

function git_kv_sha() {
    function _git_sha() {
      local path="$1"
      [[ "$path" =~ /[.]git ]] && path="$(dirname "$path")"
      test -e "$path" || return `_err $? "could not determine .git root from $1"`
      git -C "$path" describe --always --first-parent --abbrev=7 || return `_err $? "could not describe '$path'"`
    }
    for kv in $* ; do
      local k=${kv/=*/} v=${kv/*=/}
      _setenv $k=`_git_sha $v`
    done
}

git_kv_sha version_viewer_sha=$root_dir
git_kv_sha version_fsvr_sha=$fsvr_dir

version_fsvr_tag=`git -C $fsvr_dir describe --all --always|sed -e 's@.*/@@'` || exit `_err $? "!version_fsvr_tag fsvr_dir='$fsvr_dir'"`
# version_fsvr_tag=`git branch --contains "$version_fsvr_sha" --format "%(refname:lstrip=-1)"`

_setenv version_fsvr_tag=$version_fsvr_tag
_setenv version_shas="$version_viewer_sha-$version_fsvr_sha"
_setenv version_full="$version_xyzw-$version_shas"

_assert "root_dir" 'test -d $root_dir'
