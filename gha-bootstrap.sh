#!/bin/bash
echo test to stdout
echo test to stderr >&2

require_here=`readlink -f $(dirname $BASH_SOURCE)`
function require() { source $require_here/$@ ; }


function _localfetch() {
  local dir=$1 && shift
  local urls=
  for x in "$@"; do urls="$urls https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${GITHUB_REF}/$x"; done
  wget -q -P "$1" -N $urls ;
}

if [[ -n "$GITHUB_ACTIONS" ]]; then
    mkdir -pv util
    _localfetch util util/_utils.sh util/actions-cache.sh util/actions-upload.sh
fi

require util/_utils.sh

_assert base test -n "$base"
_assert repo test -n "$repo"
_assert branch test -n "$branch"

    # echo _bash=$BASH
    # echo _fsbase=$base
    # echo _fsrepo=$repo
    # echo _fsbranch=$branch
    # echo nunja_dir=$PWD/fsvr/$base
    # echo p373r_dir=$PWD/p373r-vrmod
    #
    # echo _fsvr_cache=$PWD/cache
    # test -d bin || mkdir -pv bin
    # test ! -n "$GITHUB_PATH" || { echo $PWD/bin | tee -a $GITHUB_PATH ; }
    #
    # mkdir -pv $_fsvr_cache

exit 0

