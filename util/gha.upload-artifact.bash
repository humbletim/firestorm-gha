#!/bin/bash

# bash gha helper for uploading artifacts; depends on @actions/artifact
# -- 2023.03.20 humbletim

# usage: 
#  upload_artifacts <name> "<paths>" [retention-days=1] [compression-level=0]
function upload-artifact() {(
    set -Euo pipefail

    local PATH="$PATH:/usr/bin"
    local node="/c/Program Files/nodejs/node"
    local script="/d/a/_actions/actions/upload-artifact/v4/dist/upload/index.js"

    test -f $script || { echo "$script missing" >&2 ; return 7; }
    test -v ACTIONS_RUNTIME_TOKEN || { echo "env ACTIONS_RUNTIME_TOKEN missing" >&2 ; return 8; }

    local -a inputs=(
      INPUT_name=$(printf "%q" "$1")
      INPUT_path=$(printf "%q" "$2")
      INPUT_retention-days=${3:-1}
      INPUT_compression-level=${4:-0}
      INPUT_overwrite=false
      INPUT_if-no-files-found=error
    )
    
    echo "----------------------------------------" >&2
    echo "env ${inputs[@]} $node $script" >&2
    echo "----------------------------------------" >&2
    eval "env ${inputs[@]} $node $script"
    echo "----------------------------------------" >&2
)}

