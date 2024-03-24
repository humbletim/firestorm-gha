#!/bin/bash
set -Euo pipefail

_PRESHELL_PATH="${_PRESHELL_PATH:-}"
PATH="$PATH:/usr/bin"

fsvr_dir="${fsvr_dir:-$PWD/fsvr}"

if [[ $OSTYPE == msys ]] ; then
  function _cygpath() { cygpath -ua "$1"; }

  _workspace=$(cygpath -ua "${workspace:-${GITHUB_WORKSPACE:-.}}" | sed 's@/$@@')
  _userprofile=$(cygpath -ua "$USERPROFILE")
  _programfiles=$(cygpath -ua "$PROGRAMFILES") # | /usr/bin/sed -e 's@[cC]:/@/c/@')
  _comspec=$(cygpath -ua "$COMSPEC") # | /usr/bin/sed -e 's@[cC]:/@/c/@')

  _PATH="$_workspace/bin:$_userprofile/bin:/c/tools/zstd:$_programfiles/Git/bin:$_programfiles/Git/usr/bin:$_programfiles/Git/mingw64/bin:/c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts:/c/hostedtoolcache/windows/Python/3.9.13/x64:$_programfiles/OpenSSL/bin:/c/Windows/System32/OpenSSH:$_programfiles/nodejs:$_programfiles/LLVM/bin:/c/ProgramData/Chocolatey/bin:$_programfiles/CMake/bin:/c/Windows/system32:/usr/bin:/bin:/c/msys64/usr/bin"

else
  _PATH="$PWD/bin:$PATH"
fi

######################################################################
echo "$(cat<<EOF
export fsvr_dir="$fsvr_dir"

_PRESHELL_PATH="$_PRESHELL_PATH"
_PATH="$_PATH"

test ! -f $PWD/gha-bootstrap.env    || source $PWD/gha-bootstrap.env
test ! -f $PWD/build/build_vars.env || source $PWD/build/build_vars.env

_xpath="\$_PATH"
[[ -v msvc_path ]] && _xpath="\$msvc_path:\$_xpath"
[[ -n "\$_PRESHELL_PATH" ]] && _xpath="\$_xpath:\$_PRESHELL_PATH"
declare -x PATH="\$_xpath"

function _err() { local rc=\$1 ; shift; echo "[_err rc=\$rc] \$@" >&2; return \$rc; }

function ht-ln() { '$fsvr_dir/util/_utils.sh' ht-ln "\$@" ; }
function hostname(){ echo 'windows-2022' ; }
function tee() { TEE="`which tee`" "`which python3`" "$fsvr_dir/util/tee.py" "\$@" ; }
function colout() { PYTHONPATH="$(pwd -W)/bin/colout" "`which python3`" -c 'import signal;setattr(signal,"SIGPIPE",signal.SIGFPE);import sys;sys.argv[0]="colout.py";__import__("colout").main()' "\$@" ; }
function parallel() { PARALLEL_HOME="$PWD/bin/parallel-home" "$PWD/bin/parallel" "\$@" ; }

function fsvr_step() { set -Euo pipefail; $PWD/fsvr/util/build.sh "\$@" ; }

declare -xf _err tee parallel ht-ln hostname fsvr_step
set -Eo pipefail
EOF
)"
