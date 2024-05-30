#!/bin/bash
#set -Euo pipefail

function get_ninja-windows() {(
    set -Euo pipefail
    local archive=$( wget-sha256 \
        bbde850d247d2737c5764c927d1071cbb1f1957dcabda4a130fa8547c12c695f \
        https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-win.zip \
      .
    ) && unzip -d bin $archive || return `_err $? "failed to provision ninja $?"`
    ls -l bin/ | grep ninja
)}

function get_colout() {(
    set -Euo pipefail
    python -m pip install --break-system-packages --no-warn-script-location --user colout
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
    local archive=$( wget-sha256 \
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
function get_yaml2json-windows() {(
    set -Euo pipefail
    local archive=$( wget-sha256 \
        a73fb27e36e30062c48dc0979c96afbbe25163e0899f6f259b654d56fda5cc26 \
        https://github.com/bronze1man/yaml2json/releases/download/v1.3/yaml2json_windows_amd64.exe\
      .
    ) && cp -avu $archive bin/yaml2json.exe || return `_err $? "failed to provision yaml2json.exe $?"`
    ls -l bin/ | grep yaml2json
)}

function gha-populate-bin-windows() {(
  set -Euo pipefail
  echo cache_id=$cache_id
  test -d "$fsvr_dir" || exit 50
  test -n "$cache_id" || exit 51
  wget --version      || exit 52

  source $ghash/gha.cachette.bash
  source $ghash/gha.ht-ln.bash

  export BASH
  function generate_BASH_FUNC_invoke() {
    source $gha_fsvr_dir/bashland/BASH_FUNC/gha.alias-exe.bash
    BASH=$(cygpath -was "$BASH") make-stub bin/BASH_FUNC_invoke.exe || return 90
  }

  gha-cache-restore-fast $cache_id-BASH_FUNC_invoke bin/BASH_FUNC_invoke.exe || (
    generate_BASH_FUNC_invoke
    gha-cache-save-fast $cache_id-BASH_FUNC_invoke bin/BASH_FUNC_invoke.exe || exit 89
  )

  {
    ht-ln bin/BASH_FUNC_invoke.exe bin/ht-ln.exe
    ht-ln bin/BASH_FUNC_invoke.exe bin/hostname.exe
    ht-ln bin/BASH_FUNC_invoke.exe bin/jq.exe
    ht-ln bin/BASH_FUNC_invoke.exe bin/envsubst.exe
  } || exit 86

  function xxtest_bin() {
    test -f bin/parallel-home/will-cite || return 196
    parallel --version | head -1        || return 197
    ninja --version | head -1           || return 198
    [[ `hostname` =~ windows[-]?2022 ]] || return 199
    jq --version | head -1              || return 200
    which parallel.exe
    which colout
    which jq
  }

  function xxprovision_tools() {(
    set -Euo pipefail
    source $ghash/gha.wget-sha256.bash
    source $ghash/gha.literally-exists.bash
    pysite="$(cygpath -m "$(python3 -msite --user-site)")"

    literally-exists bin/ninja.exe    || get_ninja-windows    || exit `_err $? "failed to provision ninja $?"`
    literally-exists $pysite/colout   || get_colout   || exit `_err $? "failed to provision colout $?"`
    literally-exists bin/parallel     || get_parallel || exit `_err $? "failed to provision parallel $?"`
    literally-exists bin/colout.exe   || ht-ln bin/BASH_FUNC_invoke.exe bin/colout.exe
    literally-exists bin/parallel.exe || ht-ln bin/BASH_FUNC_invoke.exe bin/parallel.exe

    # note: autobuild is not necessary here, but viewer_manifest still depends on python-llsd
    python -m pip install --no-warn-script-location --user llsd
  )}

  gha-cache-restore-fast $cache_id-bin-b bin || (
    xxprovision_tools || exit `_err $? "!xxprovision_tools"` 
    xxtest_bin || exit `_err $? "!xxtest_bin"`
    gha-cache-save-fast $cache_id-bin-b bin || exit 85
  )

  python3 --version || exit 119
)}

