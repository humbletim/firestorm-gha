#!/bin/bash
set -Euo pipefail

# env | grep -E '^[_a-z][a-z]'

_workspace=$(/usr/bin/cygpath -ua "${workspace:-$GITHUB_WORKSPACE}")
_userprofile=$(/usr/bin/cygpath -ua "$USERPROFILE")
_programfiles=$(/usr/bin/cygpath -ua "$PROGRAMFILES") # | /usr/bin/sed -e 's@[cC]:/@/c/@')
_comspec=$(/usr/bin/cygpath -ua "$COMSPEC") # | /usr/bin/sed -e 's@[cC]:/@/c/@')
_PRESHELL_PATH="$PATH"

if [[ -v GITHUB_WORKSPACE ]]; then
  TEE=c:/msys64/usr/bin/tee.exe
  WGET=c:/msys64/usr/bin/wget.exe
  ENVSUBST=c:/msys64/usr/bin/envsubst.exe
  PYTHON=/c/hostedtoolcache/windows/Python/3.9.13/x64/python3.exe 
else
  TEE=`which tee`
  WGET=`which wget`
  ENVSUBST=`which envsubst`
  PYTHON=`which python3`
fi

PATH="$_workspace/bin:$_userprofile/bin:/c/tools/zstd:$_programfiles/Git/bin:$_programfiles/Git/usr/bin:/c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts:/c/hostedtoolcache/windows/Python/3.9.13/x64:$_programfiles/OpenSSL/bin:/c/Windows/System32/OpenSSH:$_programfiles/nodejs:$_programfiles/LLVM/bin:/c/ProgramData/Chocolatey/bin:$_programfiles/CMake/bin:/c/Windows/system32:/usr/bin:/bin:/c/msys64/usr/bin"

#. $(dirname $0)/util/_utils.sh 
_PRESHELL_PATH=
#`subtract_paths "$_PRESHELL_PATH" "$PATH"`

######################################################################
echo "$(cat<<EOF
_PRESHELL_PATH="$_PRESHELL_PATH"
_workspace="$_workspace"
_userprofile="$_userprofile"
_programfiles="$_programfiles"
_comspec="$_comspec"
_PATH="$PATH"

_xpath="\$_PATH"
if [[ -v msvc_path ]]; then _xpath="\$(/usr/bin/cygpath -p "\$msvc_path"):\$_xpath" ; fi
if [[ -n "\$_PRESHELL_PATH" ]]; then _xpath="\$_xpath:\$_PRESHELL_PATH" ; fi

set -a
base="$base"
repo="$repo"
branch="$branch"
fsvr_dir="$PWD/fsvr"

test ! -f $PWD/gha-bootstrap.env    || source $PWD/gha-bootstrap.env
test ! -f $PWD/build/build_vars.env || source $PWD/build/build_vars.env

function _err() { local rc=\$1 ; shift; echo "[_err rc=\$rc] \$@" >&2; return \$rc; }
function tee() { TEE="$TEE" "$PYTHON" "$fsvr_dir/util/tee.py" "\$@" ; }
function hostname() { "$PWD/bin/hostname.exe" "\$@" ; }
function ninja() { "$PWD/bin/ninja.exe" "\$@" ; }
function parallel() { PARALLEL_HOME="$PWD/bin/parallel-home" "$PWD/bin/parallel" "\$@" ; }
function envsubst() { "$ENVSUBST" "\$@" ; }
function wget() { "$WGET" "\$@" ; }
function fsvr_step() { set -Euo pipefail; $PWD/fsvr/util/build.sh "\$@" ; }

declare -xf _err tee hostname parallel wget envsubst ninja fsvr_step
declare -x PATH="\$_xpath"
set +a
set -Eo pipefail
EOF
)"
