#!/bin/bash
test -d "$build_dir" || { echo "!build_dir" >&2; exit 1; }
test -d "$source_dir" || { echo "!source_dir" >&2; exit 1; }

here="$(readlink -f $(dirname $0))"
cd "$here"
echo "$(jq --sort-keys '. + $p' --argjson p "$(jq '.' meta/packages-info.json)" $build_dir/packages-info.json)" > $build_dir/packages-info.json
jq '.["p373r-vrmod"]' $build_dir/packages-info.json
cd $source_dir/newview
grep P373R llviewerdisplay.cpp >/dev/null || patch -p1 < $here/0001-P373R-6.6.8-baseline-diff.patch

test -d "$_fsvr_dir" && grep p373r_dir $_fsvr_dir/build_vars.env || { echo "p373r_dir=$(cygpath -ma $here)" | tee -a $_fsvr_dir/build_vars.env ; }

