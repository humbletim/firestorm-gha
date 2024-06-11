#!/bin/bash

# helper to download + checksum verify using wget
# usage: wget-sha256 <sha256sumhex> <url> <outputdir>
#  returns the resulting outputdir/filename to stdout
# -- humbletim 2024.03.20

function wget-sha256() {(
  set -Euo pipefail
  export PATH="$PATH:/usr/bin"
  local hash="$1" url="$2" dir="${3:-.}"
  local filename=$(basename "$url")
  test ! -d "$dir" || cd "$dir"
  wget -q -N "$url" >&2 || { local ec=$? ; echo "wget $url failed $ec" >&2 ; return $ec ; }
  echo "$hash $filename" | sha256sum --strict --check >&2 || return $?
  echo "$dir/$filename"
)}
