#!/bin/bash
set -Euo pipefail

function is_gha() { [[ -v GITHUB_ACTIONS ]] ; }

function _err() { local rc=$1 ; shift; echo "[gha-bootstrap rc=$rc] $@" >&2; return $rc; }

# LITERALLY determine whether an EXACT filename ACTUALLY exists
# NOTE: `ls bin/parallel` (even `stat 'bin/parallel'`) both falsely
# match when there exists a `bin/parallel.exe`; as of yet no known
# way to prevent such false existential positives; hence the long route here...
function literally_exists() {
  local dir="$(dirname "$1")"
  local name="$(basename "$1")"
  command -p ls -1a "$dir" | command -p grep -Fx "$name" >/dev/null && true || false
}

function quiet_clone() {(
    set -Euo pipefail
    echo "[gha-bootstrap] quiet_clone $1 $2 $3" >&2
    if [[ $2 =~ [a-f0-9]{40} ]]; then
      # "branch" refers to a fully-qualified git hash; clone + reset rather than --branch
      git clone --quiet https://github.com/$1 $3 2>&1 | grep -vE '^(remote:|Receive|Resolve)' \
       && git -C "$3" reset --hard "$2"
    else
      git clone --quiet --filter=tree:0 --single-branch \
          https://github.com/$1 --branch $2 $3 2>&1 | grep -vE '^(remote:|Receive|Resolve)' || true
    fi
    test -d $3/.git || return 1
    git -C "$3" describe --all --always
)}

function initialize_firestorm_checkout() {(    
    set -Euo pipefail
)}

function get_ninja() {(
    set -Euo pipefail
    local archive=$( $fsvr_dir/util/_utils.sh wget-sha256 \
        bbde850d247d2737c5764c927d1071cbb1f1957dcabda4a130fa8547c12c695f \
        https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-win.zip \
      .
    ) && unzip -d bin $archive || return `_err $? "failed to provision ninja $?"`
    ls -l bin/ | grep ninja
)}



function get_colout_babel() {(
    set -Euo pipefail
    local archive=$( $fsvr_dir/util/_utils.sh wget-sha256 \
        ad76eab6905b626d7d4110d2032bc60c69bef225ec94c67d7229425ebe53f659 \
        https://github.com/python-babel/babel/archive/refs/tags/v2.14.0.tar.gz \
      .
    ) || return `_err $? "failed to download babel $?"`
    mkdir -pv bin/.colout/babel
    tar -C bin/.colout --force-local --strip-components=1 \
      -xf $archive babel-2.14.0/{babel,scripts,cldr} || return `_err $? "failed to provision babel $?"`
    python bin/.colout/scripts/download_import_cldr.py 2>/dev/null || return `_err $? "failed to localize babel $?"`
    ls -l bin/.colout | grep babel
)}

function get_colout_pygments() {(
    set -Euo pipefail
    local archive=$( $fsvr_dir/util/_utils.sh wget-sha256 \
        163e0235b3739c24d7631bb7b0e5829f9ea081c10b26662354c3ba0e6e95f8ea \
        https://github.com/pygments/pygments/archive/refs/tags/2.17.2.tar.gz \
      .
    ) || return `_err $? "failed to download pygments $?"`
    mkdir -pv bin/.colout/pygments
    tar -C bin/.colout --force-local --strip-components=1 \
      -xf $archive pygments-2.17.2/pygments || return `_err $? "failed to provision pygments $?"`
    ls -l bin/.colout | grep pygments
)}

function get_colout() {(
    set -Euo pipefail
    mkdir bin/.colout -pv
    PYTHONUSERBASE="$(cygpath -wa bin/.colout)" python -m pip install --user colout
    ./fsvr/util/_utils.sh ht-ln bin/.colout/Python39/site-packages/colout bin/.colout/colout/colout
    ./fsvr/util/_utils.sh ht-ln bin/.colout/Python39/site-packages/pygments bin/.colout/colout/pygments
    ./fsvr/util/_utils.sh ht-ln bin/.colout/Python39/site-packages/babel bin/.colout/colout/babel
    echo hello world | colout "hello" "red" | colout "world" "blue"
    # local archive=$( $fsvr_dir/util/_utils.sh wget-sha256 \
    #     b44caa1754be29edcd30d31a9c65728061546f605a889e8d4ffbb2df281e8d44 \
    #     https://github.com/nojhan/colout/archive/refs/tags/v1.1b.tar.gz \
    #   .
    # ) || return `_err $? "failed to download colout $?"`
    # mkdir -pv bin/.colout
    # tar -C bin/.colout --force-local --strip-components=2 --exclude=colout-1.1b/colout/colout_clang.py \
    #   -xf $archive colout-1.1b/colout || return `_err $? "failed to provision colout $?"`
    # ls -la bin/ | grep .colout
    # get_colout_pygments
    # get_colout_babel
)}

function get_parallel() {(
    set -Euo pipefail
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
  ls -l bin/ | grep parallel
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
