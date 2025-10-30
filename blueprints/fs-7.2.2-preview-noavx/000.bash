#!/bin/bash

avx2_nunja_dir=$(dirname ${nunja_dir})

# clone avx2 blueprint
cp -av `find $avx2_nunja_dir/ -maxdepth 1 -type f | fgrep -v 000.bash` $nunja_dir/

# and de-avx2-ify it
perl -i -pe 's@--avx2=ON@--avx2=OFF@g' *
perl -i'' -pe 's@ ?(/arch:AVX2|-DUSE_AVX2_OPTIMIZATION)@@g' *

fgrep -i avx2 * >&2

# source the original 000.bash
. ${avx2_nunja_dir}/000.bash
