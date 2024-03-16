#!/bin/bash

# create variables with git commit short hashes from checkout folders
# -- humbletim 2024.03.08

source `dirname $BASH_SOURCE`/_utils.sh  # for _setenv, _die

test -n "$*" || _die 'usage: $0 [varname=gitdir] [varname2=gitdir2] ...'

# example:
#   ./util/generate_git_vars.sh source_sha=. openvr_sha=../openvr
#
#   # which exports environment vars and emits on stdout:
#   source_sha=a1b2c3d
#   openvr_sha=9f8e7d6


# git active commit short hash for a checkout folder
function _git_sha() {
  local path=$1
  [[ "$path" ==~ .*/.git ]] && path=$(dirname $path)
  test -d $path || _die "could not determine .git root from $1"
  git -C $path describe --always --first-parent --abbrev=7 || _die "could not describe $path"
}
set -e
for kv in $* ; do
  k=${kv/=*/}
  v=${kv/*=/}
  _setenv $k=`_git_sha $v`
done
