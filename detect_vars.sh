#!/bin/bash
set -e
self="${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}"
here=$(dirname $(readlink -f "$self"))

function _setenv() { printf "%q\n" "$@" && export "$@" ; }

_setenv workspace=${GITHUB_WORKSPACE:-$(readlink -f "$here/..")}
_setenv root_dir=$(cygpath -ma "$workspace" 2>/dev/null || echo "$workspace")
_setenv _fsvr_dir=$(cygpath -ma "$here" 2>/dev/null || echo "$here")
_setenv source_dir=$root_dir/indra

_setenv viewer_channel=FirestormVR-GHA

_setenv AUTOBUILD_CONFIGURATION=ReleaseFS_open
_setenv AUTOBUILD_ADDRSIZE=64
_setenv AUTOBUILD_VSVER=170
_setenv AUTOBUILD_VARIABLES_FILE=$workspace/fs-build-variables/variables
_setenv AUTOBUILD_INSTALLABLE_CACHE=$workspace/autobuild-cache
_setenv AUTOBUILD_CONFIG_FILE=$workspace/autobuild.xml

_setenv build_vcdir=build-vc${AUTOBUILD_VSVER}-${AUTOBUILD_ADDRSIZE}
_setenv build_dir=${build_dir:-"$root_dir/$build_vcdir"}
_setenv packages_dir=$build_dir/packages

_version=$(cat $build_dir/newview/viewer_version.txt)
function vercomp() { echo $_version | cut -d "." -f $1 ; }

_setenv version_major=`vercomp 1`
_setenv version_minor=`vercomp 2`
_setenv version_patch=`vercomp 3`
_setenv version_release=`vercomp 4`
_setenv version_git_sha=`git -C $workspace describe --always --first-parent --abbrev=7`
_setenv version_build_sha=`git -C "$build_dir" describe --always --first-parent --abbrev=7`
_setenv version_string="${version_major}.${version_minor}.${version_patch}.${version_release}"
_setenv version_sha="${version_git_sha}-${version_build_sha}"
_setenv version_full="${version_string}-${version_sha}"

eval $(echo $(basename $build_dir) | grep -Eo 'build-vc[0-9]+-[0-9]+' | sed -e 's@^build-vc\([0-9]*\)-\([0-9]*\)$@_vsver=\1 _addrsize=\2@')

test $_vsver == $AUTOBUILD_VSVER || { echo "_vsver='$_vsver' but AUTOBUILD_VSVER=$AUTOBUILD_VSVER" ; exit 32 ; }
test $_addrsize == $AUTOBUILD_ADDRSIZE || { echo "_addrsize='$_addrsize' but AUTOBUILD_ADDRSIZE=$AUTOBUILD_ADDRSIZE" ; exit 33 ; }
test $_version == $version_string || { echo "_version='$_version' but version_string='$version_string'" ; exit 34 ; }
