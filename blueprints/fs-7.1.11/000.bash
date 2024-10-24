#!/bin/bash
maybe-clone viewer ${hub:-github.com} $repo "$ref"
maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8
pushd repo/viewer
  patch -p1 < $nunja_dir/../fs-7.1.11/installer_template.nsi.patch
  git diff
popd