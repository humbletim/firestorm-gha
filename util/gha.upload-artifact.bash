#!/bin/bash

# bash gha helper for uploading artifacts; depends on @actions/artifact
# -- 2023.03.20 humbletim

# usage:
#  upload_artifacts <name> "<paths>" [retention-days=1] [compression-level=0] [overwrite=false]

source $(dirname $BASH_SOURCE)/gha._utils.bash

function gha-upload-artifact() {(
    set -Euo pipefail
    gha-have-runtime || { echo "gha runtime unavailable" && exit 13 ; }

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_artifact_dir="${actions_artifact_dir:-/d/a/_actions/actions/upload-artifact/v4}"
    local script="${script:-${actions_artifact_dir}/dist/upload/index.js}"

    local -a Input=(
      INPUT_name="`gha-esc "$1"`"
      INPUT_path="`gha-esc "$2"`"
      INPUT_retention-days=${3:-1}
      INPUT_compression-level=${4:-0}
      INPUT_overwrite=${5:-false}
      INPUT_if-no-files-found=error # warn | error | ignore
    )

    local -A Check=(
      [retention-days]='[0-9]+'
      [compression-level]='[0-9]'
      [overwrite]='(false|true)'
      [if-no-files-found]='(warn|error|ignore)'
    )
    for i in "${!Check[@]}"; do
      gha-assert Input "$i" "${Check[$i]}"
    done || exit `gha-err 36 "???"`

    local -a Command=(
      `gha-esc "$node"`
      `gha-esc "$script"`
    )

    local -A Raw
    gha-invoke-action Input Command Raw

    if [[ -n ${Raw[outputs:error]+_} ]] ; then
      gha-assoc-to-json Raw #rc inputs outputs found
      echo "[$FUNCNAME] ERROR: : ${Raw[outputs:error]}"
      exit 178
    fi

    if [[ -n ${Raw[outputs:artifact-id]+_} ]] ; then
      echo "[$FUNCNAME] OK!"
      gha-assoc-to-json Raw rc outputs found
      exit 0
    else
      gha-assoc-to-json Raw #rc inputs outputs found
      echo "[$FUNCNAME] ERROR: artifact-id not found..."
      exit 160
    fi

    # local -a Output=(
    #     artifact-id
    #     artifact-url
    # )

)}

