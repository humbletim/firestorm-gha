#!/bin/bash

avx2_nunja_dir=${nunja_dir/p373r-/}

pushd $nunja_dir
  # clone avx2 blueprint
  /usr/bin/find $avx2_nunja_dir/ -maxdepth 1 -type f ! -name 000.bash -exec cp -av {} ./ \;
popd

# source the original 000.bash
. ${avx2_nunja_dir}/000.bash

# and p373r-ify it
rm -vf repo/p373r
ls -l repo/
ht-ln repo/p373r-vrmod/p373r repo/p373r
