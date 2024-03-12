#!/bin/bash

fdbgopts="set -Eou pipefail ; trap 'echo err \$? ; exit 1' ERR"

set -Euo pipefail
echo test to stdout
echo test to stderr >&2

echo base=$base repo=$repo branch=$branch >&2

_gha_PATH=`echo "$(cat <<EOF
/c/tools/zstd
/c/Program Files/Git/bin
/c/Program Files/Git/usr/bin
/c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts
/c/hostedtoolcache/windows/Python/3.9.13/x64
/c/Program Files/OpenSSL/bin
/c/Windows/System32/OpenSSH
/c/Program Files/nodejs
/c/Program Files/LLVM/bin
/c/ProgramData/Chocolatey/bin
EOF
)" | tr '\n' ':'`


# function dup_to_stderr() { $USERPROFILE/bin/bash -c 'tee >(cat >&2)' ;  }

function initialize_gha_shell() {
    local userhome=`cygpath -ua $USERPROFILE`
    mkdir -pv $userhome/bin
    fsvr_path="$userhome/bin:$fsvr_path"
    if [[ ! -s $userhome/.github_token && -n "$GITHUB_TOKEN" ]]; then
      echo "$GITHUB_TOKEN" > $userhome/.github_token
    fi
    # cherry-pick msys64 (to avoid bringing in msys64/usr/bin/*.* to PATH)
    cp -uav 'c:/msys64/usr/bin/wget.exe' $userhome/bin/
    # cp -uav 'c:/msys64/usr/bin/more.exe' $userhome/bin/
    # cp -uav 'c:/Program Files/Git/usr/bin/bash.exe' $userhome/bin/
    # cp -uav 'c:/msys64/usr/bin/tee.exe' $userhome/bin/
    # cp -uav 'c:/msys64/usr/bin/cat.exe' $userhome/bin/
    # cp -uav 'c:/Program Files/Git/usr/bin/tar.exe' bin/
    # export PATH=$userhome/bin:$PATH

    mkdir -pv bin cache node_modules

    test -d node_modules/@actions/cache || {
        echo "[gha-bootstrap] installing @actions/cache" >&2
        npm install --no-save @actions/cache 2>/dev/null
    } || _die "[gha-bootstrap] npm i @actions/cache failed $?"
}

function initialize_fsvr_gha_checkout() {
    test -d fsvr/.git || {
      git clone --quiet --filter=tree:0 --single-branch --branch $fsvr_branch \
      https://github.com/$fsvr_repo fsvr
    }
}

function _restore_gha_cache() {
    local id=$1
    local cache_id=undefined
    if [[ -s restored_$id && `cat restored_$id` != undefined ]]; then
        echo "restored_$id exists; skipping" >&2
        cache_id=`cat restored_$id`
    else
        cache_id=$($_fsvr_dir/util/actions-cache.sh restore "$@") \
            || _die "[gha-bootstrap] actions-cache restore $id  failed $?"
        if [[ $cache_id != undefined ]]; then
            echo $cache_id > restored_$id
        fi
    fi
    echo $cache_id
}

restored_bin_id=undefined
restored_node_modules_id=undefined

function restore_gha_caches() {
    restored_bin_id=$(_restore_gha_cache $base-bin-a bin) \
        || _die "[gha-bootstrap] actions-cache restore bin failed $?"
    echo restored_bin_id=$restored_bin_id >&2

    restored_node_modules_id=$(_restore_gha_cache $base-node_modules-a node_modules) \
        || _die "[gha-bootstrap] actions-cache restore node_modules failed $?"
    echo restored_node_modules_id=$restored_node_modules_id >&2
}

function ensure_gha_bin() {
    set -Euo pipefail
    declare -A wgets=(
        [ninja]="
            bbde850d247d2737c5764c927d1071cbb1f1957dcabda4a130fa8547c12c695f
            https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-win.zip
        "
        [parallel]="
            3f9a262cdb7ba9b21c4aa2d6d12e6ccacbaf6106085fdaafd3b8a063e15ea782
            https://mirror.msys2.org/msys/x86_64/parallel-20231122-1-any.pkg.tar.zst
        "
    )

    if [[ $restored_bin_id == undefined ]]; then
        echo "[gha-bootstrap] provisioning ninja and parallel" >&2
        test -f bin/ninja.exe || {
            archive=`wget_sha256 ${wgets[ninja]} .`
            unzip -d bin $archive
        } || _die "[gha-bootstrap] failed to provision ninja $?"

        test -x bin/hostname.exe || {
            # avoid entropy by hard-coding hostname used by parallel and other tools
            alias gcc="/c/Program\ Files/LLVM/bin/clang"
            echo '
              #include <stdio.h>
              int main(int argc, char *argv[]) { printf(MESSAGE); return 0; }
            ' | gcc "-DMESSAGE=\"windows2022\"" -x c - -o bin/hostname.exe
        } || _die "[gha-bootstrap] failed to provision hostname.exe $?"

        test -x bin/parallel || {

            archive=`wget_sha256 ${wgets[parallel]} .`
            tar -C bin --strip-components=2 -vxf $archive usr/bin/parallel

            echo 65535 > bin/parallel-home/tmp/sshlogin/`hostname`/linelen

                # hereby recognize contributions of GNU Parallel, developed by O. Tange.
            echo "
              Tange, O. (2022, November 22). GNU Parallel 20221122 ('Херсо́н').
              Zenodo. https://doi.org/10.5281/zenodo.7347980
            " | PARALLEL_HOME/will-cite
        } || _die "[gha-bootstrap] failed to provision parallel $?"

    fi
    if [[ $restored_node_modules_id == undefined ]]; then
        local npmi=$(for x in @actions/artifact @actions/github ; do
            test -d node_modules/$x || echo $x
        done)
        test -n "$npmi" && {
            echo "[gha-bootstrap] npm i $npmi" >&2
            npm install --no-save $npmi 2>/dev/null
        }
    fi
}

function save_gha_caches() {
    set -Euo pipefail
    (
      set -e
      parallel --version | head -1
      echo -n 'ninja: ' ; ninja --version
      _assert hostname [[ `hostname` == windows2022 ]]
    ) || _die "[gha-bootstrap] testbin failed"

    ls -1d node_modules/@actions/{core,github,cache,artifact} \
        || _die "[gha-bootstrap] npm @actions setup incomplete"

    [[ "$restored_bin_id" != undefined ]] || {
        echo "[gha-bootstrap] attempting to save bin cache... $restored_bin_id" >&2
        $_fsvr_dir/util/actions-cache.sh save $base-bin-a bin || return 1
    }

    [[ "$restored_node_modules_id" != undefined ]] || {
        echo "[gha-bootstrap] attempting to save node_modules cache restored_node_modules_id" >&2
        $_fsvr_dir/util/actions-cache.sh save $base-node_modules-a node_modules || return 1
    }
}

function is_gha() { [[ -v GITHUB_ACTIONS ]] ; }
if is_gha; then
    echo "[gha-bootstrap] GITHUB_ACTIONS=$GITHUB_ACTIONS" >&2
    fsvr_path="$(cygpath -ua bin):$_gha_PATH"
    fsvr_repo=${GITHUB_REPOSITORY}
    fsvr_branch=${GITHUB_REF_NAME}
    fsvr_base=$base
    initialize_gha_shell || exit 100
    initialize_fsvr_gha_checkout || exit 99
    _fsvr_dir=fsvr
else
    echo "[gha-bootstrap] local dev testing mode" >&2
    # fsvr_path="$(cygpath -ua bin):$PATH"
    _fsvr_dir=.
    fsvr_path="$PATH"
    fsvr_repo=local
    fsvr_branch=`git branch --show-current`
    fsvr_base=`echo $fsvr_branch | grep -Eo '\b[0-9]+[.][0-9]+[.][0-9]+'`
fi

export PATH=$fsvr_path
echo PATH=$PATH | tee PATH.env

require_here=`readlink -f ${_fsvr_dir:-fsvr}`
function require() { source $require_here/$@ ; }

require util/_utils.sh

is_gha && ( restore_gha_caches || _die "!restore_gha_caches" )

is_gha && ( ensure_gha_bin || _die "!ensure_gha_bin")
is_gha && ( save_gha_caches || _die "!save_gha_caches")

_assert base test -n "$base"
_assert repo test -n "$repo"
_assert branch test -n "$branch"

pwd=`_realpath $PWD`

vars="$(cat <<EOF
    _bash=$BASH
    _fsbase=$base
    _fsrepo=$repo
    _fsbranch=$branch
    fsvr_base=$fsvr_base
    fsvr_repo=$fsvr_repo
    fsvr_branch=$fsvr_branch
    fsvr_path=$fsvr_path
    nunja_dir=$pwd/fsvr/$base
    p373r_dir=$pwd/p373r-vrmod
    _home=`_realpath ~`
    _home_bin=$pwd/bin
    _fsvr_cache=$pwd/cache
    _path=$fsvr_path
    PARALLEL_HOME=$pwd/bin/parallel-home
EOF
)"

echo ""

cmds="$(echo "$vars" | sed -e 's@^ *@_setenv @')"
eval "$cmds" | tee gha-bootstrap.env

exit 0
