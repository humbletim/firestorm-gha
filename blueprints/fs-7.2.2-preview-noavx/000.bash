#!/bin/bash

avx2_nunja_dir=${nunja_dir/noavx/avx2}

pushd $nunja_dir
  # clone avx2 blueprint
  /usr/bin/find $avx2_nunja_dir/ -maxdepth 1 -type f ! -name 000.bash -exec cp -av {} ./ \;

  # and de-avx2-ify it
  perl -i'' -pe 's@--avx2=ON@--avx2=OFF@g' *
  perl -i'' -pe 's@ ?(/arch:AVX2|-DUSE_AVX2_OPTIMIZATION)@@g' *

  # confirm no residue
  fgrep -i avx2 * >&2

popd

# source the original 000.bash
. ${avx2_nunja_dir}/000.bash
