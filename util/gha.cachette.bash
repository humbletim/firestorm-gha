#!/bin/bash

# bash gha helper for saving and restoring caches
# depends on workflow-level `uses: actions/cache@v4` and running within a node20/ACTIONS_RUNTIME_TOKEN enabled context
# -- 2023.03.22 humbletim

source $(dirname $BASH_SOURCE)/gha._utils.bash

function gha-cache-exists() {(
    set -Euo pipefail
    gha-have-runtime || { echo "gha runtime unavailable" && exit 13 ; }
    # gha-have-runtime || return `gha-err $? gha runtime unavailable`

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_cache_dir="${actions_cache_dir:-/d/a/_actions/actions/cache/v4}"
    local script="${script:-${actions_cache_dir}/dist/restore-only/index.js}"

    local -a Input=(
        INPUT_key="`gha-esc "$1"`"
        INPUT_path="`gha-esc "$2"`"
        INPUT_lookup-only=true
        INPUT_fail-on-cache-miss=false
        # INPUT_upload-chunk-size=
        # INPUT_restore-keys=
    )

    gha-check Input fail-on-cache-miss '(true|false)' || return 2
    gha-check Input lookup-only        '(true|false)' || return 2

    local -a Command=(
      `gha-esc "$node"`
      `gha-esc "$script"`
    )

    local -A Raw
    gha-invoke-action Input Command Raw

    local -A TextMap=(
      [outputs:error]='Cache not found for input keys: '
      [found:resource-url]='Resource Url: '
      [found:file-size]='File Size: '
      [found:cache-size]='Cache Size: '
      [found:resolved-keys]='Resolved Keys:..debug. '
    )

    local -A Found
    gha-match-text-entries TextMap Found "${Raw[data:stdout]:-}" "${Raw[data:stderr]:-}"
    gha-merge-arrays Raw Found

    if [[ -n ${Raw[outputs:error]:-} ]] ; then
      gha-assoc-to-json Raw #rc inputs outputs found
      echo "[$FUNCNAME] ERROR: : ${Raw[outputs:error]}"
      exit 178
    fi

    if [[ ${Raw[outputs:cache-matched-key]:-} == $1 ]] ; then
      echo "[$FUNCNAME] OK!"
      gha-assoc-to-json Raw rc outputs found
      exit 0
    else
      gha-assoc-to-json Raw #rc inputs outputs found
      echo "[$FUNCNAME] ERROR: cache-matched-key not found..."
      exit 160
    fi

    # if [[ $(jq -r '.["cache-matched-key"]' <<< "$json") == $1 ]]; then exit 0 ; else exit -1 ; fi

    # local -a Output=(
    #     cache-hit
    #     cache-primary-key
    #     cache-matched-key
    # )

    # local -a State=(
    #   CACHE_KEY
    #   CACHE_RESULT
    # )

)}

function gha-cache-restore() {(
    set -Euo pipefail
    gha-have-runtime || { echo "gha runtime unavailable" && exit 13 ; }

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_cache_dir="${actions_cache_dir:-/d/a/_actions/actions/cache/v4}"
    local script="${script:-${actions_cache_dir}/dist/restore-only/index.js}"

    local -a Input=(
        INPUT_key="`gha-esc "$1"`"
        INPUT_path="`gha-esc "$2"`"
        INPUT_lookup-only=false
        INPUT_fail-on-cache-miss=true
        # INPUT_upload-chunk-size=
        # INPUT_restore-keys=
    )

    gha-check Input fail-on-cache-miss '(true|false)' || return 2
    gha-check Input lookup-only        '(true|false)' || return 2

    local -a Command=(
      `gha-esc "$node"`
      `gha-esc "$script"`
    )

    local -A Raw
    gha-invoke-action Input Command Raw

    local -A TextMap=(
      [outputs:error]='Cache not found for input keys: '
      [found:resource-url]='Resource Url: '
      [found:cache-restored-key]='Cache restored from key: '
      [found:file-size]='File Size: '
      [found:cache-size]='Cache Size: '
      [found:resolved-keys]='Resolved Keys:..debug. '
    )

    local -A Found
    gha-match-text-entries TextMap Found "${Raw[data:stdout]:-}" "${Raw[data:stderr]:-}"
    gha-merge-arrays Raw Found

    if [[ -n ${Raw[outputs:error]:-} ]] ; then
      gha-assoc-to-json Raw #rc inputs outputs found
      echo "[$FUNCNAME] ERROR: : ${Raw[outputs:error]}"
      exit 178
    fi

    if [[ ${Raw[outputs:cache-matched-key]:-} == $1 ]] ; then
      echo "[$FUNCNAME] OK!"
      gha-assoc-to-json Raw rc outputs found
      exit 0
    else
      gha-assoc-to-json Raw #rc inputs outputs found
      echo "[$FUNCNAME] ERROR: cache-matched-key not found..."
      exit 160
    fi

#     local -a Output=(
#         cache-hit
#         cache-primary-key
#         cache-matched-key
#     )

#     local -a State=(
#       CACHE_KEY
#       CACHE_RESULT
#     )

)}


function gha-cache-save() {(
    set -Euo pipefail
    gha-have-runtime || { echo "gha runtime unavailable" && exit 13 ; }

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_cache_dir="${actions_cache_dir:-/d/a/_actions/actions/cache/v4}"
    local script="${script:-${actions_cache_dir}/dist/save-only/index.js}"

    local -a Input=(
        INPUT_key="`gha-esc "$1"`"
        INPUT_path="`gha-esc "$2"`"
        # INPUT_upload-chunk-size=
        # INPUT_enableCrossOsArchive=
    )

    local -a Command=(
      `gha-esc "$node"`
      `gha-esc "$script"`
    )

    local -A Raw
    gha-invoke-action Input Command Raw

    local -A TextMap=(
      [outputs:cache-saved-key]='Cache saved with key: '
      [outputs:error]='Failed to save: '
      [found:resource-url]='Resource Url: '
      [found:file-size]='File Size: '
      [found:cache-size]='Cache Size: '
    )

    local -A Found
    gha-match-text-entries TextMap Found "${Raw[data:stdout]:-}" "${Raw[data:stderr]:-}"
    gha-merge-arrays Raw Found

    if [[ -n ${Raw[outputs:error]:-} ]] ; then
      echo "[$FUNCNAME] ERROR: : ${Raw[outputs:error]}"
      exit 178
    fi

    if [[ ${Raw[outputs:cache-saved-key]:-} == $1 ]] ; then
      echo "[$FUNCNAME] OK!"
      gha-assoc-to-json Raw rc outputs found
      exit 0
    else
      gha-assoc-to-json Raw #rc inputs outputs found
      echo "[$FUNCNAME] ERROR: cache-saved-key not found..."
      exit 160
    fi

    # local -a Output=(
    #     cache-hit
    #     cache-primary-key
    #     cache-matched-key
    # )

    # local -a State=(
    #   CACHE_KEY
    #   CACHE_RESULT
    # )

)}

function gha-cache-restore-fast() {(
  test -v GITHUB_ACTIONS || return 1
  set -Euo pipefail
  export INPUT_key="$1" INPUT_path="$2"
  /c/Program\ Files/nodejs/node /d/a/_actions/actions/cache/v4/dist/restore-only/index.js \
    | grep -i 'cache restored' >&2 && return 0
  echo "(cache not restored: ${INPUT_key})" >&2
  return 1
)}

function gha-cache-save-fast() {(
  test -v GITHUB_ACTIONS || return 0
  set -Euo pipefail
  export INPUT_key="$1" INPUT_path="$2"
  /c/Program\ Files/nodejs/node /d/a/_actions/actions/cache/v4/dist/save-only/index.js || return $?
  echo "cache saved: ${INPUT_key}" >&2
)}
