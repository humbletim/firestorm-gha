#!/bin/bash

# bash gha helper for uploading artifacts; depends on @actions/artifact
# -- 2023.03.20 humbletim

# usage: 
#  upload_artifacts <name> "<paths>" [retention-days=1] [compression-level=0]

source $(dirname $BASH_SOURCE)/gha._utils.bash

function upload-artifact() {(
    set -Euo pipefail

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_artifact_dir="${actions_artifact_dir:-/d/a/_actions/actions/upload-artifact/v4}"
    local script="${script:-${actions_artifact_dir}/dist/upload/index.js}"

    local -a Input=(
      INPUT_name="`gha-esc "$1"`"
      INPUT_path="`gha-esc "$2"`"
      INPUT_if-no-files-found=error # warn | error | ignore
      INPUT_retention-days=${3:-1}
      INPUT_compression-level=${4:-0}
      INPUT_overwrite=false
    )

    local -a Command=(
      `gha-esc "$node"`
      `gha-esc "$script"`
    )

    # local -a Output=(
    #     artifact-id
    #     artifact-url
    # )

    local -a Invocation=("${Input[@]}" "${Command[@]}")

    echo "----------------------------------------" >&2
    # declare -p Invocation 
    echo "----------------------------------------" >&2
    gha-invoke-action "${Invocation[@]}"
    echo "----------------------------------------" >&2
)}

