#!/bin/bash

# fsvr script utilities -- humbletim 2024.03.08

_fsvr_utils_dir=$(readlink -f $(dirname "$BASH_SOURCE"))

source $_fsvr_utils_dir/gha.reduce-paths.bash
source $_fsvr_utils_dir/gha.wget-sha256.bash
source $_fsvr_utils_dir/gha.ht-ln.bash
source $_fsvr_utils_dir/gha.cygpath.bash

_dbgopts='set -Euo pipefail'

_die_exit_code=128
function _die() { echo -e "[_die] error: $@" >&2 ; exit ${_die_exit_code:-1} ; }
function _err() { local rc=$1 ; shift; echo "[_err rc=$rc] $@" >&2; return $rc; }

# assert "message" [test expression...]
function _assert() {
  #echo "[_assert $@]" >&2
  local message="$1" && shift
  local debug=/dev/null #/dev/stderr
  eval "$@" && echo "_assert OK $@ $message" >&2 > $debug || _die "[_assert] assertion failed: $@\n$message"
}

# reverse-susbstitute well known paths for use as tidier debug logging
function _relativize() {
    test ! -v DEBUG || { echo "$@" ; return 0; }
    local rel="$@"
    for x in build_dir source_dir root_dir gha_fsvr_dir fsvr_dir fsvr_cache_dir nunja_dir p373r_dir openvr_dir ; do
      test ! -v $x || rel=${rel//${!x}/\{${x}\}}
    done
    echo $rel
}

#_getenv bypasses bash variables and queries system-level environment (via env)
# usage: _getenv NAME
function _getenv(){ /usr/bin/env | /usr/bin/grep -E "^$1=" | /usr/bin/cut -d '=' -f 2- || true ; }

# extract environment variable value
# while supporting hyphens in names AND ALSO newlines/etc. in values
# eg: local value="$(__getenv INPUT_x-y-z)"
function __getenv() {
  local eenv="$(printf "%q" "$( echo ; env ; echo )")"
  eenv="$(echo "$eenv" | sed -E 's@\\n?([-_A-Za-z0-9%.]+)=@\n\n\n\1=@g')"
  local evalue="$(echo "$eenv" | grep -Eo "^$1=.*" | cut -d '=' -f 2-)"
  echo -e "$evalue" | sed "s@\\\'@'@g;"
}

# _setenv exports and emits to stdout a canonicalized name=value argument
# escaping attempts to emerge both ninja and bash compatible variable assignments
# example scenarios and escaping:
# _setenv key=value                   => key=value
# _setenv key="value with spaces"     => key="value with spaces"
# _setenv "key=value with spaces"     => key=value\ with\ spaces
# _setenv "key=value;with;semicolons" => key=value\;with\;semicolons

function _setenv() {
  local vargs="$@" # sqaush args
  local name="${vargs/=*/}"
  local value="${vargs/#$name=/}"
  if [[ $value == *=* ]] ; then echo "[_setenv warning] assignment '$@' contains multipe ='s; treating as '$name={$value}'" >&2 ; fi
  export "$name=$value"
  # unless quoted then escape spaces, backslashes and semicolons
  echo "$value" | grep -E "^[^\"]+[ \\;]" >/dev/null && value="$(printf '%q\n' "$value")"
  echo "$name=$value"
}

# like above but _setenv_extant also verifies value of "key=value" exists as a filepath
function _setenv_extant() {
  local name="${@/=*/}"
  local value="${@/#$name=/}"
  test -e "$value" || [[ "$value" == \$* ]] || { echo "ERROR: _setenv_extant $@ value=$value does not exist" >&2 ; exit 1; }
  _setenv "$@"
}

# like above but _setenv_ma also encodes using cygpath -ma conventions
function _setenv_ma() {
  local name="${@/=*/}"
  local value="${@/#$name=/}"
  value=`_realpath $value`
  test -e "$value" || [[ "$value" == \$* ]] || { echo "ERROR: _setenv_extant $@ value=$value does not exist" >&2 ; exit 1; }
  _setenv "$name=$value"
}

function _realpath() { cygpath -ma "$1" 2>/dev/null || readlink -f "$1"; }
function _relative_path() { realpath --relative-to "$2" "$1" ; }


# usage: __utils_main__ ${BASH_SOURCE[0]} ${0}
#   => if first argument is a declared function, invoke with args
#      (otherwise no-op)
function __utils_main__() {
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if declare -f "$1" &>/dev/null; then
        # echo "__main__ ${BASH_SOURCE[0]} ${0}" >&2
        function_name=$1
        shift
        $function_name "$@" || _die "invocation $function_name $@ failed $?"
    fi
  fi
}

__utils_main__ "$@"
