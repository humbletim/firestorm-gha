#!/bin/bash

mkdir -pv repo/p373r
echo $BASH_SOURCE -- skipping > repo/p373r/applied

gha-cache-restore-fast $cache_id-repo-0001 repo/viewer || (
    set -Euo pipefail
    quiet-clone ${hub:-github.com} $repo $ref repo/viewer

    pushd repo/viewer
      curl https://patch-diff.githubusercontent.com/raw/FirestormViewer/phoenix-firestorm/pull/25.patch | patch -p1 || exit $?
      git diff
    popd

  gha-cache-save-fast $cache_id-repo-0001 repo/viewer  || exit 15
)
