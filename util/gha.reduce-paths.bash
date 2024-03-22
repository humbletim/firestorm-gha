#!/bin/bash

# bash helper to reduce/subtract/dedupe PATH sets while preserving order
# NOTE: assumes unix style colon-separated '/c/Program Files:/d/a/path/bin' paths
# -- humbletim 2024.03.20

# usage:
#    reduce-paths(A) => (A) deduplicated / normalized
#    reduce-paths(A, B) => (A - B) deduplicated / normalized

function reduce-paths() {(
  set -Euo pipefail
  PATH="$PATH:/usr/bin"
  grep -x -vf <(echo "$2" | tr ':' '\n') <(echo "${1:-}" | tr ':' '\n') \
    | awk '!seen[$0]++' | tr '\n' ':' | sed 's@::@:@g;s@[: ]*$@@g'
  return 0
)}
