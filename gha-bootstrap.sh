#!/bin/bash
echo test to stdout $ACTIONS_CACHE_URL
echo test to stderr >&2

set -Euo pipefail

fdbgopts="set -Eou pipefail ; trap 'echo err \$? ; exit 1' ERR"


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
)" | tr '\n' ':' | sed -e 's@^:@@;s@:$@@'`

# ( while read line; do cygpath -ua "$line" ; done ) | 

# function dup_to_stderr() { $USERPROFILE/bin/bash -c 'tee >(cat >&2)' ;  }
fsvr_path="$PATH"

function _err() { local rc=$1 ; shift; echo "[gha-bootstrap rc=$rc] $@" >&2; return $rc; }

function initialize_gha_shell() {
    set -Euo pipefail
    local userhome=`cygpath -ua $USERPROFILE`
    mkdir -pv $userhome/bin
    fsvr_path="$userhome/bin:$fsvr_path"
    # if [[ ! -s $userhome/.github_token && -v GITHUB_TOKEN ]]; then
    #   echo "$GITHUB_TOKEN" > $userhome/.github_token
    # fi
    # cherry-pick msys64 (to avoid bringing in msys64/usr/bin/*.* to PATH)
    cp -uav 'c:/msys64/usr/bin/wget.exe' $userhome/bin/
    # cp -uav 'c:/msys64/usr/bin/more.exe' $userhome/bin/
    # cp -uav 'c:/Program Files/Git/usr/bin/bash.exe' $userhome/bin/
    # cp -uav 'c:/msys64/usr/bin/tee.exe' $userhome/bin/
    # cp -uav 'c:/msys64/usr/bin/cat.exe' $userhome/bin/
    # cp -uav 'c:/Program Files/Git/usr/bin/tar.exe' bin/
    # export PATH=$userhome/bin:$PATH

    mkdir -pv bin cache #node_modules

    # test -d node_modules/@actions/cache || {
    #     echo "[gha-bootstrap] installing @actions/cache" >&2
    #     "/c/Program Files/nodejs/npm" install --no-save @actions/cache 2>/dev/null
    # } || return `_err $? "npm i @actions/cache failed"`
}

function quiet_clone() {
    echo "[gha-bootstrap] quiet_clone $1 $2 $3" >&2
    git clone --quiet --filter=tree:0 --single-branch \
        https://github.com/$1 --branch $2 $3 2>&1 | grep -vE '^(remote:|Receive|Resolve)' || true
    test -d $3/.git || return 1
}

function initialize_fsvr_gha_checkout() {
    set -Euo pipefail
    test -d fsvr/.git || quiet_clone $fsvr_repo $fsvr_branch fsvr
}

function initialize_firestorm_checkout() {
    set -Euo pipefail
    test -d repo/$branch/.git || quiet_clone $repo $branch repo/$branch
    test -d repo/fs-build-variables/.git || quiet_clone FirestormViewer/fs-build-variables master repo/fs-build-variables
    test -d repo/p373r || quiet_clone ${GITHUB_REPOSITORY} P373R_6.6.8 repo/p373r
}

function actions_cache_v4_save_only() {
    INPUT_key=$1 INPUT_path=$2 "/c/Program Files/nodejs/node" \
        /d/a/_actions/actions/cache/v4/dist/save-only/index.js \
        | tr '\r' '\n' | grep -vE '^$|::debug::' | tee actions_cache_v4_save_only.$1.log
    grep -vE '^$|::debug::' actions_cache_v4_save_only.$1.log >&2
}

function actions_cache_v4_restore_only() {
    INPUT_key=$1 INPUT_path=$2 "/c/Program Files/nodejs/node" \
        /d/a/_actions/actions/cache/v4/dist/restore-only/index.js \
        | tr '\r' '\n' | grep -vE '^$' | tee actions_cache_v4_restore_only.$1.log \
        | grep -Eo 'restored from key: .*$' | grep -Eo '[^ ]+$'
    grep -vE '^$|::debug::' actions_cache_v4_restore_only.$1.log >&2
}

function _restore_gha_cache() {
    set -Euo pipefail
    local id=$1
    local cache_id=
    if [[ -s restored_$id && `cat restored_$id` != "" ]]; then
        echo "[gha-bootstrap] restored_$id exists; skipping" >&2
        cache_id=`cat restored_$id`
    else
        echo "[gha-bootstrap] restoring restored_$id ..." >&2
        # cache_id=$(NODE_DEBUG=1 $_fsvr_dir/util/actions-cache.sh restore "$@")
        cache_id=$(actions_cache_v4_restore_only "$@") \
            || return `_err $? "actions-cache restore $id failed $?"`
        if [[ $cache_id != "" ]]; then
            echo $cache_id > restored_$id
        fi
    fi
    echo $cache_id
}

restored_bin_id=
# restored_node_modules_id=
restored_repo_id=

function restore_gha_caches() {
    set -Euo pipefail
    for x in bin repo ; do
        local vid=restored_${x}_id
        local id=$(_restore_gha_cache $base-$x-b $x) \
            || return `_err $? "actions-cache restore $x failed $?"`
        echo "XXXXXXXXXXXXXXXXX $vid=$id" >&2
        eval "$vid=$id"
        echo "[gha-bootstrap] $vid=${!vid}" >&2
    done
}

function save_gha_caches() {
    # ls -1d node_modules/@actions/{core,github,cache,artifact} \
    #     || return `_err $? "npm @actions setup incomplete"`

    for x in bin repo ; do
        local vid=restored_${x}_id
        [[ -n "${!vid}" ]] || {
            echo "[gha-bootstrap] attempting to save $x cache... ${!vid}" >&2
            actions_cache_v4_save_only $base-$x-b $x \
              || return `_err $? "error saving $x $vid"`
            # $_fsvr_dir/util/actions-cache.sh save $base-bin-a bin || return 1
        }
    done
}

function ensure_gha_bin() {(
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

    if [[ -z $restored_bin_id ]]; then
        echo "[gha-bootstrap] provisioning ninja and parallel" >&2
        test -f bin/ninja.exe || {
            archive=`wget_sha256 ${wgets[ninja]} .`
            unzip -d bin $archive
        } || return `_err $? "failed to provision ninja $?"`

        test -x bin/hostname.exe || {
            # avoid entropy by hard-coding hostname used by parallel and other tools
            local gcc=$(cygpath -ms '/c/Program Files/LLVM/bin/clang')
            echo '
              #include <stdio.h>
              int main(int argc, char *argv[]) { printf(MESSAGE); return 0; }
            ' | $gcc "-DMESSAGE=\"windows-2022\"" -x c - -o bin/hostname.exe
        } || return `_err $? "failed to provision hostname.exe $?"`

        test -x bin/parallel -a -f bin/parallel-home/will-cite || {
            archive=`wget_sha256 ${wgets[parallel]} .`
            tar -C bin --strip-components=2 -vxf $archive usr/bin/parallel

            mkdir -pv bin/parallel-home/tmp/sshlogin/`hostname`/
            echo 65535 > bin/parallel-home/tmp/sshlogin/`hostname`/linelen

                # hereby recognize contributions of GNU Parallel, developed by O. Tange.
            echo "
              Tange, O. (2022, November 22). GNU Parallel 20221122 ('Херсо́н').
              Zenodo. https://doi.org/10.5281/zenodo.7347980
            " > bin/parallel-home/will-cite
        } || return `_err $? "failed to provision parallel $?"`

    fi
    # if [[ -z $restored_node_modules_id ]]; then
    #     local npmi=$(for x in @actions/artifact @actions/github ; do
    #         test -d node_modules/$x || echo $x
    #     done)
    #     test -z "$npmi" || {
    #         echo "[gha-bootstrap] npm i $npmi" >&2
    #         npm install --no-save $npmi 2>/dev/null
    #     }
    # fi
)}


function is_gha() { [[ -v GITHUB_ACTIONS ]] ; }
if is_gha; then
    cd "${GITHUB_WORKSPACE}"
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
    fsvr_base=`echo $fsvr_branch | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+'`
fi

echo PATH=$fsvr_path | tee PATH.env
export "PATH=$fsvr_path"

require_here=`readlink -f ${_fsvr_dir:-fsvr}`
function require() { source $require_here/$@ ; }

require util/_utils.sh
_assert base test -n "$base"
_assert repo test -n "$repo"
_assert branch test -n "$branch"

if is_gha; then
    restore_gha_caches || _die "!restore_gha_caches"
    ensure_gha_bin || _die "!ensure_gha_bin"

    # TODO: figure out why perl needs system-level env vars for PARALLEL_HOME to work
    # (for now this replicates to the "other" non-msys home location)
    ht-ln bin/parallel-home /c/Users/runneradmin/.parallel
    
    initialize_firestorm_checkout || _die "!firestorm_checkout"

    (
      set -xEuo pipefail
      set -xe
      test -f bin/parallel-home/will-cite
      parallel --version | head -1
      ninja --version
      _assert hostname [[ `hostname` =~ windows[-]?2022 ]]
    ) || _die "bin precache test failed"
    save_gha_caches || _die "!save_gha_caches"

    echo "$(cat <<EOF
#!/bin/bash
set -a -Euo pipefail
PATH="/bin:/usr/bin:$fsvr_path:/c/Windows/system32"
. gha-bootstrap.env
. build/build_vars.env
./fsvr/util/build.sh "\$@"
EOF
)" | tee tmatecmd.sh
chmod a+x tmatecmd.sh

fi

pwd=`_realpath $PWD`

vars="$(cat <<EOF
    PARALLEL_HOME=$pwd/bin/parallel-home
    _home=`_realpath ${USERPROFILE:-$HOME}`
    _bash=$BASH
    firestorm=$repo@$base\#$branch
    fsvr=$fsvr_repo@$fsvr_branch\#$fsvr_base
    fsvr_path=$fsvr_path
    nunja_dir=$pwd/fsvr/$base
    p373r_dir=$pwd/repo/p373r
    _fsvr_cache=$pwd/cache
EOF
)"

echo ""

cmds="$(echo "$vars" | sed -e 's@^ *@_setenv @')"
eval "$cmds" | tee gha-bootstrap.env

exit 0
