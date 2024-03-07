#!/bin/bash
test -d "$build_dir" || { echo "!build_dir" >&2; exit 1; }
test -d "$source_dir" || { echo "!source_dir" >&2; exit 1; }

here="$(readlink -f $(dirname $0))"
cd "$here"
echo "$(jq --sort-keys '. + $p' --argjson p "$(jq '.' meta/packages-info.json)" $build_dir/packages-info.json)" > $build_dir/packages-info.json
cd $source_dir/newview
patch -p1 < $here/0001-P373R-6.6.8-baseline-diff.patch
