#!/bin/bash

# WIP -- attempt minimal CI/CD clone of the github repo branch folder - humbletim 2024.03.31
function quiet-clone() {(
    local repo="$1" ref="$2" folder="$3"
    set -Euo pipefail
    echo "[gha-bootstrap] quiet_clone $repo $ref $folder" >&2
    if [[ $ref =~ [a-f0-9]{40} ]]; then
      # "branch" refers to a fully-qualified git hash; clone + reset rather than --branch
      git clone --quiet https://github.com/$repo $folder 2>&1 | grep -vE '^(remote:|Receive|Resolve)' \
       && git -C $folder reset --hard $ref
    else
      git clone --quiet --filter=tree:0 --single-branch \
          https://github.com/$repo --branch $ref $folder 2>&1 | grep -vE '^(remote:|Receive|Resolve)' || true
    fi
    test -e $folder/.git || return 1
    git -C $folder describe --all --always
)}
