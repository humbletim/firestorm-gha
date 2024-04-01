#!/bin/bash
set -e
source $(dirname "$BASH_SOURCE")/_utils.sh

viewer_version=$1
test $(echo "$1" | grep -Eo '[.]' | wc -l) == 3 || _die "expected x.y.z.w got '$1'"

_setenv viewer_version=$viewer_version
_setenv version_major=`  _ver_split $viewer_version 1`
_setenv version_minor=`  _ver_split $viewer_version 2`
_setenv version_patch=`  _ver_split $viewer_version 3`
_setenv version_release=`_ver_split $viewer_version 4`
_setenv version_xyz=$version_major.$version_minor.$version_patch
_setenv version_xyzw=$version_xyz.$version_release
_setenv slos_version=$viewer_version
