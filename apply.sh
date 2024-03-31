#!/bin/bash
test -d "$source_dir" || { echo "!source_dir" >&2; exit 1; }

here="$(readlink -f $(dirname $0))"
cd $source_dir/newview
grep P373R llviewerdisplay.cpp >/dev/null || patch --ignore-whitespace --verbose --merge -p1 < $here/20240331.diff.U.patch

