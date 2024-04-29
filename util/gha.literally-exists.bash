#!/bin/bash

# LITERALLY determine whether an EXACT filename ACTUALLY exists
# NOTE: `ls bin/parallel` (even `stat 'bin/parallel'`) both falsely
# match when there exists a `bin/parallel.exe`; as of yet no known
# way to prevent such false existential positives; hence the long route here...
function literally-exists() {
  local dir="$(dirname "$1")"
  local name="$(basename "$1")"
  command -p ls -1a "$dir" 2>/dev/null | command -p grep -Fx "$name" >/dev/null && true || false
}
