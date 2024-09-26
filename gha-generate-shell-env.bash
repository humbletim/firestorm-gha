#!/bin/bash
set -Euo pipefail

_PRESHELL_PATH="${_PRESHELL_PATH:-}"
_SYSTEM_PATH="${PATH:-}"
PATH="$PATH:/usr/bin"

gha_fsvr_dir="$(dirname "${BASH_SOURCE}")"
_hostname="windows-2022"

if [[ $OSTYPE == msys ]] ; then
  _workspace=$(cygpath -ua "${workspace:-${GITHUB_WORKSPACE:-.}}" | sed 's@/$@@')
  _userprofile=$(cygpath -ua "$USERPROFILE")
  _programfiles=$(cygpath -ua "$PROGRAMFILES") # | /usr/bin/sed -e 's@[cC]:/@/c/@')
  _comspec=$(cygpath -ua "$COMSPEC") # | /usr/bin/sed -e 's@[cC]:/@/c/@')

  _PATH="$_workspace/bin:$_userprofile/bin:/c/tools/zstd:$_programfiles/Git/bin:$_programfiles/Git/usr/bin:$_programfiles/Git/mingw64/bin:/c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts:/c/hostedtoolcache/windows/Python/3.9.13/x64:$_programfiles/OpenSSL/bin:/c/Windows/System32/OpenSSH:$_programfiles/nodejs:$_programfiles/LLVM/bin:/c/ProgramData/Chocolatey/bin:$_programfiles/CMake/bin:/c/Windows/system32:/usr/bin:/bin:/c/msys64/usr/bin"

  export PATH="$_PATH"
  _PYTHONUSERBASE="$(cygpath -wa bin/pystuff)"

else
  _PATH="$PWD/bin:$PATH"
  _PYTHONUSERBASE="$(readlink -f bin/pystuff)"
fi

python3="$(PATH="$PATH:$_PRESHELL_PATH" which python3)"
$python3 --version >/dev/null || { echo "!python3" 2>&1 ; exit 26 ; }

jqexe="$(PATH="$_SYSTEM_PATH:$_PRESHELL_PATH" which jq)"
$jqexe --version >/dev/null || { which jq ; echo "!jq" 2>&1 ; exit 27 ; }

pysite="$(PYTHONUSERBASE="$_PYTHONUSERBASE" ${python3} -msite --user-site)"

######################################################################
echo "$(cat<<EOF
export gha_fsvr_dir="$gha_fsvr_dir"
export ghash="$ghash"

_PRESHELL_PATH="$_PRESHELL_PATH"
_PATH="$_PATH"

set -a
[[ -f $PWD/env.d/local.env ]] && source $PWD/env.d/local.env
[[ -f $PWD/env.d/gha-bootstrap.env ]] && source $PWD/env.d/gha-bootstrap.env
[[ -f $PWD/env.d/build_vars.env    ]] && source $PWD/env.d/build_vars.env
set +a

_xpath="\$_PATH"
[[ -v msvc_path ]] && _xpath="\$msvc_path:\$_xpath"
[[ -n "\$_PRESHELL_PATH" ]] && _xpath="\$_xpath:\$_PRESHELL_PATH"
declare -x PATH="\$_xpath"

declare -x LANG=en_US.UTF-8
declare -x PYTHONUSERBASE="$_PYTHONUSERBASE"
declare -x PYTHONWARNINGS="ignore::SyntaxWarning,\${PYTHONWARNINGS:-}"
declare -x PYTHONOPTIMIZE=nonemptystring

function _err() { local rc=\$1 ; shift; echo "[_err rc=\$rc] \$@" >&2; return \$rc; }

function ht-ln() {( source "$ghash/gha.ht-ln.bash" && ht-ln "\$@" )}
function hostname(){ echo '$_hostname' ; }
function tee() { TEE="`which tee`" "${python3}" "$gha_fsvr_dir/util/tee.py" "\$@" ; }
function colout() { $(
  if PATH="$_SYSTEM_PATH" which colout 2>/dev/null > /dev/null ; then
    echo \"`which colout`\"
  else
    echo \"${python3}\" \"$pysite/colout/colout.py\"
  fi
) "\$@" ; }
function parallel() { PARALLEL_SHELL="$BASH" PARALLEL_HOME="$PWD/bin/parallel-home" "`which perl`" "$PWD/bin/parallel" "\$@" ; }
function jq() { "${jqexe}" $(
  # grr... detect if jq supports -b (binary)
  # otherwise... fall back to tr -d '\r' workaround
  # TODO: jq.exe also croaks if jq 'filter\r' contains LFs...
  ${jqexe} -ben 1 2>/dev/null > /dev/null
  if [[ $? == 0 ]] ; then
    echo '-b "$@"'
  else
    echo '"$@" | tr -d "\r"'
  fi
) ; }
function envsubst() { "`which envsubst`" "\$@" ; }

declare -xf _err tee parallel ht-ln hostname colout jq envsubst
# set -Eo pipefail
EOF
)"
