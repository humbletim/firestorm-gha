#!/bin/bash
set -Euo pipefail

function get_bootstrap_vars() {(
  [[ -x /usr/bin/readlink ]] && pwd=`/usr/bin/readlink -f "$PWD"` || pwd=$PWD
  if [[ -v GITHUB_ACTIONS ]] ; then
      echo "[gha-bootstrap] GITHUB_ACTIONS=$GITHUB_ACTIONS" >&2
      fsvr_repo=${GITHUB_REPOSITORY}
      fsvr_branch=${GITHUB_REF_NAME}
      fsvr_base=$base
      fsvr_dir=${fsvr_dir:-$PWD/fsvr}
  else
      echo "[gha-bootstrap] local dev testing mode" >&2
      fsvr_repo=${fsvr_repo:-local}
      fsvr_branch=${fsvr_branch:-`git branch --show-current`}
      fsvr_base=${fsvr_base:-`echo $fsvr_branch | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+'`}
      fsvr_dir=${fsvr_dir:-.}
  fi

  echo _viewer=$repo@$base#$ref
  echo _fsvr=$fsvr_repo@$fsvr_branch#$fsvr_base
  echo _home=`readlink -f "${USERPROFILE:-$HOME}"`
  echo _bash=$BASH

  case "$base" in
    sl-*) echo viewer_id=secondlife   ; echo viewer_name=SecondLife     ;;
    fs-*) echo viewer_id=firestorm    ; echo viewer_name=Firestorm      ;;
    bd-*) echo viewer_id=blackdragon  ; echo viewer_name=BlackDragon    ;;
    al-*) echo viewer_id=alchemy      ; echo viewer_name=Alchemy        ;;
  sgeo-*) echo viewer_id=sgeo         ; echo viewer_name=Sgeo           ;;
       *) echo viewer_id=unknown      ; echo viewer_name=Unknown        ;;
  esac

  function to-id() { cat | sed 's@[^-a-zA-Z0-9_.]@-@g' ; }
  echo cache_id=$(echo "$base-$repo" | to-id)
  echo build_id=$(echo "${build_id:-$fsvr_branch-$base}" | to-id)

  echo fsvr_dir=$fsvr_dir
  echo nunja_dir=`$fsvr_dir/util/_utils.sh _realpath $fsvr_dir/$base`
  echo p373r_dir=$pwd/repo/p373r
  echo viewer_dir=$pwd/repo/viewer
  echo fsvr_cache_dir=$pwd/cache

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

function get_colout() {(
    set -Euo pipefail
    python -m pip install --no-warn-script-location --user colout
    local pysite="$(python -msite --user-site)"
    if grep SIGPIPE $pysite/colout/colout.py ; then
      # workaround SIGPIPE on Win32 missing with some colout versions
      perl -i.bak -pe 's@^.*[.]SIGPIPE.*$@#$&@g' $pysite/colout/colout.py
      diff $pysite/colout/colout.py $pysite/colout/colout.py.bak
    fi
    echo hello world | colout "hello" "red" | colout "world" "blue"
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

# yaml2json < fsvr/.github/workflows/CompileWindows.yml | jq '.jobs[].steps[]| "#"+.name+"\n"+.if+"\n"+(.run // .with.run)' -r
function get_yaml2json() {(
    set -Euo pipefail
    local archive=$( $fsvr_dir/util/_utils.sh wget-sha256 \
        a73fb27e36e30062c48dc0979c96afbbe25163e0899f6f259b654d56fda5cc26 \
        https://github.com/bronze1man/yaml2json/releases/download/v1.3/yaml2json_windows_amd64.exe\
      .
    ) && cp -avu $archive bin/yaml2json.exe || return `_err $? "failed to provision yaml2json.exe $?"`
    ls -l bin/ | grep yaml2json
)}

