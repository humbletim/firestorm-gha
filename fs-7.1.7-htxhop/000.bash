#!/bin/bash

mkdir -pv repo/p373r
echo $BASH_SOURCE -- skipping > repo/p373r/applied

gha-cache-restore-fast $cache_id-repo-0000 repo/viewer || (
    set -Euo pipefail
    quiet-clone ${hub:-github.com} $repo $ref repo/viewer

    pushd repo/viewer
      patch -p1 < $nunja_dir/llworldmapmessage.htxhop.patch || exit $?
      git diff
    popd

  gha-cache-save-fast $cache_id-repo-0000 repo/viewer  || exit 15
)
