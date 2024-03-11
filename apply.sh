#!/bin/bash
test -d "$source_dir" || { echo "!source_dir" >&2; exit 1; }

here="$(readlink -f $(dirname $0))"
cd $source_dir/newview
grep P373R llviewerdisplay.cpp >/dev/null || patch -p1 < $here/0001-P373R-6.6.8-baseline-diff.patch

