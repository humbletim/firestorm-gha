#!/bin/bash
set -Euo pipefail

echo base=$base repo=$repo branch=$branch >&2

incoming_path=$PATH

function is_gha() { [[ -v GITHUB_ACTIONS ]] ; }


# fdbgopts="set -Eou pipefail ; trap 'echo err \$? ; exit 1' ERR"
# ( while read line; do cygpath -ua "$line" ; done ) |

function _err() { local rc=$1 ; shift; echo "[gha-bootstrap rc=$rc] $@" >&2; return $rc; }

function quiet_clone() {
    echo "[gha-bootstrap] quiet_clone $1 $2 $3" >&2
    git clone --quiet --filter=tree:0 --single-branch \
        https://github.com/$1 --branch $2 $3 2>&1 | grep -vE '^(remote:|Receive|Resolve)' || true
    test -d $3/.git || return 1
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
        # cache_id=$(NODE_DEBUG=1 $fsvr_dir/util/actions-cache.sh restore "$@")
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
            # $fsvr_dir/util/actions-cache.sh save $base-bin-a bin || return 1
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
            local gcc=${CC:-$(cygpath -ms '/c/Program Files/LLVM/bin/clang')}
            echo '
              #include <stdio.h>
              int main(int argc, char *argv[]) { printf("%s\n", MESSAGE); return 0; }
            ' | $gcc "-DMESSAGE=\"windows-2022\"" -x c - -o bin/hostname.exe
        } || return `_err $? "failed to provision hostname.exe $?"`

        test -x bin/tee || {
##############################################################################
cat <<'EOF' > bin/tee
#/usr/bin/env python
import sys
import os
import subprocess

def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "/dev/stderr":
        # Emulate tee behavior - copy input to both stdout and stderr
        while True:
            line = sys.stdin.readline()
            if not line:
                break
            sys.stdout.write(line)
            sys.stderr.write(line)

        # Attempt to read any remaining data (non-blocking)
        last_data = os.read(STDIN_FILENO, 1024)
        if last_data:
            sys.stdout.write(last_data.decode())
            sys.stderr.write(last_data.decode())

    else:
        # Forward to tar with remaining arguments
        sys.exitcode = subprocess.call(["/usr/bin/tee"] + sys.argv[1:])

if __name__ == "__main__":
    main()
EOF
##############################################################################
          chmod a+x bin/tee
          echo tee test | tee /dev/stderr >/dev/null
        }

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

    # for using tmate to debug, create a helper script that invokes with current paths
    echo "$(cat <<EOF | envsubst '$fsvr_path'
##############################################################################
#!/bin/bash
set -a -Euo pipefail
PATH="/bin:/usr/bin:$fsvr_path"
. gha-bootstrap.env
. build/build_vars.env
./fsvr/util/build.sh "$@"
EOF
##############################################################################
)" > tmatecmd.sh

)}

function subtract_paths() {(
  PATH=/usr/bin:/bin:$PATH
  grep -x -vf <(echo "$2" | tr ':' '\n') <(echo "$1" | tr ':' '\n') \
    | awk '!seen[$0]++' | tr '\n' ':' | sed 's@:$@@' 
  return 0
)}

if is_gha ; then
    echo "[gha-bootstrap] GITHUB_ACTIONS=$GITHUB_ACTIONS" >&2
    cd "${GITHUB_WORKSPACE}"

    programfiles=`/usr/bin/cygpath -ua "$PROGRAMFILES"`
    userprofile=`/usr/bin/cygpath -ua "$USERPROFILE"`

    _gha_PATH=$(/usr/bin/cat<<EOF | /usr/bin/tr '\n' ':' | /usr/bin/sed -e 's@^ \+@@;s@: \+@:@g;s@^:@@;s@:$@@'
      /c/tools/zstd
      ${programfiles}/Git/bin
      ${programfiles}/Git/usr/bin
      /c/hostedtoolcache/windows/Python/3.9.13/x64/Scripts
      /c/hostedtoolcache/windows/Python/3.9.13/x64
      ${programfiles}/OpenSSL/bin
      /c/Windows/System32/OpenSSH
      ${programfiles}/nodejs
      ${programfiles}/LLVM/bin
      /c/ProgramData/Chocolatey/bin
EOF
)

    fsvr_repo=${GITHUB_REPOSITORY}
    fsvr_branch=${GITHUB_REF_NAME}
    fsvr_base=$base
    fsvr_dir=${fsvr_dir:-$PWD/repo/fsvr}

    fsvr_path="$userprofile/bin:$PWD/bin:$_gha_PATH:/c/Windows/system32"
    export PATH=`subtract_paths "$fsvr_path" ""` || exit `_err $? "error"`

    mkdir -pv $userprofile/bin bin cache repo
    cp -uav c:/msys64/usr/bin/wget.exe c:/msys64/usr/bin/envsubst.exe \
      $userprofile/bin/

    echo "[gha-bootstrap] (interim) PATH=$PATH" >&2
    test -d $fsvr_dir/.git || quiet_clone $fsvr_repo $fsvr_branch $fsvr_dir || exit 99

    restore_gha_caches || exit `_err $? "!restore_gha_caches"`
    ensure_gha_bin || exit `_err 4? "!ensure_gha_bin"`

    # TODO: figure out why perl needs system-level env vars for PARALLEL_HOME to work
    # (for now this replicates to the "other" non-msys home location)
    $fsvr_dir/util/_utils.sh ht-ln bin/parallel-home $userprofile/.parallel

    initialize_firestorm_checkout || `_err $? "!firestorm_checkout"`

    (
      set -xEuo pipefail
      set -xe
      test -f bin/parallel-home/will-cite
      parallel --version | head -1
      ninja --version
      [[ `hostname` =~ windows[-]?2022 ]]
    ) || exit `_err $? "bin precache test failed"`;

    save_gha_caches || `_err $? "!save_gha_caches"`;

else
    echo "[gha-bootstrap] local dev testing mode" >&2
    fsvr_repo=${fsvr_repo:-local}
    fsvr_branch=${fsvr_branch:-`git branch --show-current`}
    fsvr_base=${fsvr_base:-`echo $fsvr_branch | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+'`}
    fsvr_dir=${fsvr_dir:-.}

    echo "[incoming_path] $incoming_path"
    fsvr_path=${fsvr_path:-$PWD/bin:/usr/bin:/bin}
    export PATH=`subtract_paths "$fsvr_path" ""`
fi

echo "[gha-bootstra] (final) PATH=$PATH" | /usr/bin/tee PATH.env >&2

pwd=`readlink -f "$PWD"`
##############################################################################
vars=$(cat <<EOF
_home=`readlink -f "${USERPROFILE:-$HOME}"`
_bash=$BASH
firestorm=$repo@$base#$branch
fsvr=$fsvr_repo@$fsvr_branch#$fsvr_base
PARALLEL_HOME=$pwd/bin/parallel-home
fsvr_path=$fsvr_path
fsvr_dir=$pwd/repo/fsvr
nunja_dir=`$fsvr_dir/util/_utils.sh _realpath $fsvr_dir/$base`
openvr_dir=$pwd/repo/openvr
p373r_dir=$pwd/repo/p373r
fsvr_cache_dir=$pwd/cache
EOF
##############################################################################
)

echo "... gha-bootstrap.env" >&2
echo "$vars" | tee gha-bootstrap.env

echo "... github_env" >&2
test ! -v GITHUB_ENV || { echo "GITHUB_ENV=${GITHUB_ENV:-}" ; cat gha-bootstrap.env | tee -a $GITHUB_ENV ; }

echo "... github_path" >&2
test ! -v GITHUB_PATH || {
  echo "GITHUB_PATH=$GITHUB_PATH"
  new_github_path=`subtract_paths "$userprofile/bin:$fsvr_path" "$incoming_path"` || exit `_err $? "error"`
  echo "[new_github_path] $new_github_path"
  cygpath -pw "$new_github_path" | tee -a "$GITHUB_PATH"
}
