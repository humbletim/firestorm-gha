#!/bin/bash
set -e
self="${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}"
here=$(dirname $(readlink -f "$self"))

function _usage() {
  test -n "$@" && echo "$1" >&2
  echo "usage: \$ [env workspace=...] detect_vars.sh [viewer_channel] [viewer_version as x.y.z.w] [build_dir]" >&2
  exit 128
}

function _setenv() {
  local name=$(echo "$@" | cut -d "=" -f 1)
  local value="${@/$name=/}"
  #echo "name=$name value=$value" >&2
  export "$name=$value"
  # deal with spaces, backslashes or semicolons unless already single-quoted
  echo "$value" | grep -E "^[^\"]+[ \\;]" >/dev/null && value="$(printf '%q\n' "$value")" #value="\"$value\""
  echo "$name=$value"  
  #declare -p $name
}
function _setenv_extant() {
  local path=$(echo "$@" | cut -d "=" -f 2)
  test -e "$path" || { echo "_setenv_extant $@ path=$path does not exist" ; exit 1; }
 _setenv "$@"
}
function _cyglike() { cygpath -ma "$(readlink -f "$1")" || readlink -f "$1"; }
function _winlike() { cygpath -ma "$(readlink -f "$1")" || readlink -f "$1"; }
function _ver_split() { echo "$1" | cut -d "." -f $2 ; }
function _git_sha() {
  test -e $1/.git || { echo "!$1/.git" 2>&1 ; return 1; }
  git -C "$1" describe --always --first-parent --abbrev=7
}


workspace=${workspace:-${GITHUB_WORKSPACE}}
viewer_channel=$1
viewer_version=$2
build_dir=$3

test -d "$workspace" || _usage "env workspace or GITHUB_WORKSPACE expected as base"
test $(echo "$viewer_version" | grep -Eo '[.]' | wc -l) == 3  || _usage "expected x.y.z.w got '$viewer_version'"
test -d "$build_dir" || _usage "build_dir=$build_dir does not exist"

_setenv viewer_channel=$viewer_channel
_setenv viewer_version=$viewer_version
_setenv_extant build_dir=`_winlike $build_dir`
_setenv_extant workspace=`_winlike $workspace`
_setenv packages_dir=$build_dir/packages
_setenv build_vcdir=`basename $build_dir`

test \
  -n "$viewer_channel" -a \
  $(echo "$viewer_version" | grep -Eo '[.]' | wc -l) == 3 -a \
  -d "$build_dir" -a -d "$workspace" \
  || _usage

_setenv_extant root_dir=${root_dir:-`_cyglike $workspace`}
_setenv_extant _fsvr_dir=${_fsvr_dir:-`_cyglike $here`}
_setenv_extant source_dir=${source_dir:-$root_dir/indra}

test -e $root_dir/.git || { echo "!$root_dir/.git" ; exit 1; }
test -e $_fsvr_dir/.git || { echo "!$_fsvr_dir/.git" ; exit 1; }


_setenv version_major=`  _ver_split $viewer_version 1`
_setenv version_minor=`  _ver_split $viewer_version 2`
_setenv version_patch=`  _ver_split $viewer_version 3`
_setenv version_release=`_ver_split $viewer_version 4`
_setenv version_git_sha=`git -C "$workspace" describe --always --first-parent --abbrev=7`
_setenv version_build_sha=`git -C "$_fsvr_dir" describe --always --first-parent --abbrev=7`
_setenv version_string="${version_major}.${version_minor}.${version_patch}.${version_release}"
_setenv version_sha="${version_git_sha}-${version_build_sha}"
_setenv version_full="${version_string}-${version_sha}"

# verify specified/calculated value alignments
test $viewer_version == $version_string || { echo "viewer_version='$viewer_version' but version_string='$version_string'" >&2 ; exit 34 ; }

#_setenv msvc_dir=$(cygpath -mas "$VCToolsRedistDir/x64/Microsoft.VC$(echo $VCToolsVersion | sed -e 's@^\([0-9]\+\)[.]\([0-9]\).*$@\1\2@').CRT/")
