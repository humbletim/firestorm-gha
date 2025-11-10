#!/bin/bash

# WIP -- attempt minimal CI/CD clone of the [hub repo ref folder] - humbletim 2024.03.31
function quiet-clone() {(
    local hub="$1" repo="$2" ref="$3" folder="$4"
    set -Euo pipefail
    if [[ "$ref" =~ [a-f0-9]{40} ]]; then
      echo "[gha-bootstrap] quiet_clone[commit] $hub $repo $ref $folder" >&2
      # "ref" refers to a fully-qualified git hash; clone + reset rather than --branch
      git clone --quiet https://$hub/$repo $folder 2>&1 | sed -E '/^(remote:|Receive|Resolve)/d' \
       && git -C $folder reset --hard "$ref"
    else
      echo "[gha-bootstrap] quiet_clone[single-branch] $hub $repo $ref $folder" >&2
      git clone --quiet --filter=tree:0 --single-branch \
          https://$hub/$repo --branch "$ref" $folder 2>&1 | sed -E '/^(remote:|Receive|Resolve)/d'
    fi
    test -e $folder/.git || return 1
    echo "https://$hub/$repo/tree/$(git -C $folder rev-parse --short HEAD)" > $folder/.gha_source
    git -C $folder describe --all --always
)}

function maybe-clone() {
  local name=$1 hub=$2 repo=$3 ref="$4"
  gha-cache-restore-fast $cache_id-repo-$name repo/$name || (
    set -Euo pipefail
    test -e repo/$name/.git || quiet-clone $hub $repo "$ref" repo/$name
    gha-cache-save-fast $cache_id-repo-$name repo/$name  || exit 107
  )
}

