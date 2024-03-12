#!/bin/bash
 
# fsvr script utilities -- humbletim 2024.03.08

_fsvr_utils_dir=$(readlink -f $(dirname "$BASH_SOURCE"))

function _dbgopts() { set -Euo pipefail ; }

_die_exit_code=128
function _die() { echo -e "[_die] error: $@" >&2 ; exit ${_die_exit_code:-1} ; }

# assert "message" [test expression...]
function _assert() {
  #echo "[_assert $@]" >&2
  local message="$1" && shift
  local debug=/dev/null #/dev/stderr
  eval "$@" && echo "_assert OK $@ $message" >&2 > $debug || _die "[_assert] assertion failed: $@\n$message"
}

# reverse-susbstitute well known paths for use as tidier debug logging
function _relativize() {
    local rel="$@"
    rel=${rel//$build_dir/\$build_dir}
    rel=${rel//$source_dir/\$source_dir}
    rel=${rel//$root_dir/\$root_dir}
    rel=${rel//$_fsvr_dir/\$_fsvr_dir}
    test -d "$_fsvr_cache" && rel=${rel//$_fsvr_cache/\$_fsvr_cache}
    test -d "$nunja_dir" && rel=${rel//$nunja_dir/\$nunja_dir}
    test -d "$p373r_dir" && rel=${rel//$p373r_dir/\$p373r_dir}
    echo $rel
}

# _setenv exports and emits to stdout a canonicalized name=value argument
# escaping attempts to emerge both ninja and bash compatible variable assignments
# example scenarios and escaping:
# _setenv key=value                   => key=value
# _setenv key="value with spaces"     => key="value with spaces"
# _setenv "key=value with spaces"     => key=value\ with\ spaces
# _setenv "key=value;with;semicolons" => key=value\;with\;semicolons

function _setenv() {
  local name="${@/=*/}"
  local value="${@/#$name=/}"
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
function _ver_split() { echo "$1" | cut -d "." -f $2 ; }
function _git_sha() {
  test -e $1/.git || { echo "ERROR: !\$1=$1/.git" >&2 ; return 1; }
  git -C "$1" describe --always --first-parent --abbrev=7
}

# helper to download + checksum verify using wget
# usage: wget_sha256 <sha256sumhex> <url> <outputdir>
#  returns the resulting outputdir/filename to stdout
function wget_sha256() {(
  set -Euo pipefail
  local hash=$1 url=$2 dir=${3:-.}
  local filename=`basename $url`
  test ! -d "$dir" || cd $dir
  wget -q -N $url >&2
  echo "$hash $filename" | sha256sum --strict --check >&2
  echo $dir/$filename
)}

# helper to create symbolic links
# usage: ht-ln <SOURCE> <destination folder/ or desired link filepath>
function ht-ln() {
  local source=$1 linkname=$2 opts=""
  test -e "$source" || { echo "source does not exist '$source'" >&2 ; return 1; }

  # ht-ln source.file dir/
  test ! -d "$source" && test -d "$linkname" && linkname=$linkname/$(basename "$source")

  # verify destination link folder exists
  test -d "$(dirname "$linkname")" || { echo "link location does not exist '$(dirname "$linkname")'" >&2 ; return 1; }

  # default to linux style hard links
  local cmd="ln -v $source $linkname"

  # but on Windows / msys use mklink instead
  if [[ "$OSTYPE" == "msys" ]]; then
    # note: /J junctions are used; /D directory symbolic links is another option to consider
    test -d $source && opts="/J"
    test -f $source && opts="/H"
    cmd="env MSYS_NO_PATHCONV=1 cmd.exe /C \"mklink $opts $(cygpath -w $linkname) $(cygpath -w $source)\""
  fi

  _relativize "[ht-ln] $cmd" >&2
  test -e "$linkname" && { false && _relativize "skipping (exists) $linkname" >&2 ; return 0; }
  eval "$cmd"
}

# usage: __main__ ${BASH_SOURCE[0]} ${0}
#   => if first argument is a declared function, invoke with args
#      (otherwise no-op)
function __main__() {
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if declare -f "$1" &>/dev/null; then
        # echo "__main__ ${BASH_SOURCE[0]} ${0}" >&2
        function_name=$1
        shift
        eval "$function_name $@" || _die "invocation $function_name $@ failed $?"
    fi
  fi
}

__main__ "$@"
