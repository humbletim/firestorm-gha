#!/bin/bash
set -Euo pipefail

echo base=$base repo=$repo branch=$branch >&2

incoming_path=$PATH

function is_gha() { [[ -v GITHUB_ACTIONS ]] ; }

# fdbgopts="set -Eou pipefail ; trap 'echo err \$? ; exit 1' ERR"

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

# function actions_cache_v4_save_only() {
#     INPUT_key=$1 INPUT_path=$2 "/c/Program Files/nodejs/node" \
#         /d/a/_actions/actions/cache/v4/dist/save-only/index.js \
#         | tr '\r' '\n' | grep -vE '^$|::debug::' | tee actions_cache_v4_save_only.$1.log
#     grep -vE '^$|::debug::' actions_cache_v4_save_only.$1.log >&2
# }
# 
# function actions_cache_v4_restore_only() {
#     INPUT_key=$1 INPUT_path=$2 "/c/Program Files/nodejs/node" \
#         /d/a/_actions/actions/cache/v4/dist/restore-only/index.js \
#         | tr '\r' '\n' | grep -vE '^$' | tee actions_cache_v4_restore_only.$1.log \
#         | grep -Eo 'restored from key: .*$' | grep -Eo '[^ ]+$'
#     grep -vE '^$|::debug::' actions_cache_v4_restore_only.$1.log >&2
# }
# 
# function _restore_gha_cache() {
#     set -Euo pipefail
#     local id=$1
#     local cache_id=
#     if [[ -s restored_$id && `cat restored_$id` != "" ]]; then
#         echo "[gha-bootstrap] restored_$id exists; skipping" >&2
#         cache_id=`cat restored_$id`
#     else
#         echo "[gha-bootstrap] restoring restored_$id ..." >&2
#         # cache_id=$(NODE_DEBUG=1 $fsvr_dir/util/actions-cache.sh restore "$@")
#         cache_id=$(actions_cache_v4_restore_only "$@") \
#             || return `_err $? "actions-cache restore $id failed $?"`
#         if [[ $cache_id != "" ]]; then
#             echo $cache_id > restored_$id
#         fi
#     fi
#     echo $cache_id
# }
# 
# restored_bin_id=
# restored_repo_id=
# 
# function restore_gha_caches() {
#     set -Euo pipefail
#     for x in bin repo ; do
#         local vid=restored_${x}_id
#         local id=$(_restore_gha_cache $base-$x-b $x) \
#             || return `_err $? "actions-cache restore $x failed $?"`
#         echo "XXXXXXXXXXXXXXXXX $vid=$id" >&2
#         eval "$vid=$id"
#         echo "[gha-bootstrap] $vid=${!vid}" >&2
#     done
# }
# 
# function save_gha_caches() {
#     # ls -1d node_modules/@actions/{core,github,cache,artifact} \
#     #     || return `_err $? "npm @actions setup incomplete"`
# 
#     for x in bin repo ; do
#         local vid=restored_${x}_id
#         [[ -n "${!vid}" ]] || {
#             echo "[gha-bootstrap] attempting to save $x cache... ${!vid}" >&2
#             actions_cache_v4_save_only $base-$x-b $x \
#               || return `_err $? "error saving $x $vid"`
#             # $fsvr_dir/util/actions-cache.sh save $base-bin-a bin || return 1
#         }
#     done
# }
# 
function get_ninja() {(
    local archive=$( $fsvr_dir/util/_utils.sh wget-sha256 \
        bbde850d247d2737c5764c927d1071cbb1f1957dcabda4a130fa8547c12c695f \
        https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-win.zip \
      .
    ) && unzip -d bin $archive || return `_err $? "failed to provision ninja $?"`
    ls -l bin/ninja.exe
)}

function get_parallel() {(
    local archive=$( $fsvr_dir/util/_utils.sh wget-sha256 \
      3f9a262cdb7ba9b21c4aa2d6d12e6ccacbaf6106085fdaafd3b8a063e15ea782 \
      https://mirror.msys2.org/msys/x86_64/parallel-20231122-1-any.pkg.tar.zst \
      .
    ) && tar -C bin --strip-components=2 -vxf $archive usr/bin/parallel && {
      mkdir -pv bin/parallel-home/tmp/sshlogin/`hostname`/
      echo 65535 > bin/parallel-home/tmp/sshlogin/`hostname`/linelen
      mkdir -pv bin/parallel-home/tmp/sshlogin/`/usr/bin/hostname`/
      echo 65535 > bin/parallel-home/tmp/sshlogin/`/usr/bin/hostname`/linelen
      test ! -v HOSTNAME || mkdir -pv bin/parallel-home/tmp/sshlogin/$HOSTNAME/
      test ! -v HOSTNAME || echo 65535 > bin/parallel-home/tmp/sshlogin/$HOSTNAME/linelen
      # hereby recognize contributions of GNU Parallel, developed by O. Tange.
      echo "
        Tange, O. (2022, November 22). GNU Parallel 20221122 ('Херсо́н').
        Zenodo. https://doi.org/10.5281/zenodo.7347980
      " > bin/parallel-home/will-cite
  } || return `_err $? "failed to provision parallel $?"`
  ls -l bin/parallel
)}

# function get_hostname() {(
#     # avoid entropy by hard-coding hostname used by parallel and other tools
#     local gcc=${CC:-$(cygpath -ms '/c/Program Files/LLVM/bin/clang')}
#   {
#     echo '
#       #include <stdio.h>
#       #include <io.h>
#       extern int _setmode(int, int);
#       #define _O_BINARY 0x8000
#       //#include <fnctl.h>
#       int main(int argc, char *argv[]) { _setmode(1,_O_BINARY); printf("%s\n", MESSAGE); return 0; }
#     ' | $gcc "-DMESSAGE=\"$1\"" -x c - -o bin/hostname.exe
#   } || return `_err $? "failed to provision hostname.exe $?"`
#   ls -l bin/hostname.exe
# )}

# LITERALLY determine whether an EXACT filename ACTUALLY exists
# NOTE: `ls bin/parallel` (even `stat 'bin/parallel'`) both falsely
# match when there exists a `bin/parallel.exe`; as of yet no known
# way to prevent such false existential positives; hence the long route here...
function literally_exists() {
  local dir="$(dirname "$1")"
  local name="$(basename "$1")"
  command -p ls -1 "$dir" | command -p grep -Fx "$name" >/dev/null && true || false
}

function ensure_gha_bin() {(
    set -Euo pipefail
    echo "[gha-bootstrap] provisioning bin/ tools" >&2
    literally_exists bin/ninja.exe || get_ninja    || return `_err $? "failed to provision ninja $?"`
    literally_exists bin/parallel  || get_parallel || return `_err $? "failed to provision parallel $?"`
)}

function get_bootstrap_vars() {(
  [[ -x /usr/bin/readlink ]] && pwd=`/usr/bin/readlink -f "$PWD"` || pwd=$PWD
  if is_gha ; then
      echo "[gha-bootstrap] GITHUB_ACTIONS=$GITHUB_ACTIONS" >&2
  else
      echo "[gha-bootstrap] local dev testing mode" >&2
      fsvr_repo=${fsvr_repo:-local}
      fsvr_branch=${fsvr_branch:-`git branch --show-current`}
      fsvr_base=${fsvr_base:-`echo $fsvr_branch | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+'`}
      fsvr_dir=${fsvr_dir:-.}
  fi

  echo _home=`readlink -f "${USERPROFILE:-$HOME}"`
  echo _bash=$BASH
  echo firestorm=$repo@$base#$branch
  echo fsvr=$fsvr_repo@$fsvr_branch#$fsvr_base
  echo fsvr_dir=$fsvr_dir
  echo nunja_dir=`$fsvr_dir/util/_utils.sh _realpath $fsvr_dir/$base`
  echo p373r_dir=$pwd/repo/p373r
  echo fsvr_cache_dir=$pwd/cache
)}
