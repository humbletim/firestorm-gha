#!/bin/bash

#maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8
mkdir -pv repo/p373r
echo $BASH_SOURCE -- skipping > repo/p373r/applied

gha-cache-restore $cache_id-repo-0000 repo/viewer || (
    set -Euo pipefail
    quiet-clone ${hub:-github.com} $repo $ref repo/viewer

    pushd repo/viewer

    git -c user.email=CITEST -c user.name=CITEST \
      am $nunja_dir/VR_Sgeo_2024_Firestor_7.1.10.all-inclusive-working-with-openvrh.patch

  git diff
  # git -C repo/viewer diff
  popd

  gha-cache-save $cache_id-repo-0000 repo/viewer  || exit 37
)
