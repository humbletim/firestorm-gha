#!/bin/bash

# bash gha helper for saving and restoring caches
# depends on workflow-level `uses: actions/cache@v4` and running within a node20/ACTIONS_RUNTIME_TOKEN enabled context
# -- 2023.03.22 humbletim

source $(dirname $BASH_SOURCE)/gha._utils.bash

# key, path, restore-keys, upload-chunk-size, enableCrossOsArchive, fail-on-cache-miss, lookup-only

function gha-cache-exists() {(
    set -Euo pipefail

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_cache_dir="${actions_cache_dir:-/d/a/_actions/actions/cache/v4}"
    local script="${script:-${actions_cache_dir}/dist/restore-only/index.js}"

    local -a Input=(
        INPUT_key="`gha-esc "$1"`"
        INPUT_path="`gha-esc "$2"`"
        INPUT_lookup-only=true
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

    local json="$(gha-invoke-action "${Input[@]}" "${Command[@]}")"
    echo "$json"
    if [[ $(jq -r '.outputs["cache-hit"]' <<< "$json") == true ]]; then exit 0 ; else exit 38 ; fi
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

    local json="$(gha-invoke-action "${Input[@]}" "${Command[@]}")"
    echo "$json"
    if [[ $(jq -r '.outputs["cache-hit"]' <<< "$json") == true ]]; then exit 0 ; else exit -1 ; fi

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

    local json="$(gha-invoke-action "${Input[@]}" "${Command[@]}")"
    local raw="$(jq -r '.data.stdout+"\n"+.data.stderr' <<< "$json")"
    if [[ $raw =~ \ Failed\ to\ save:\ ([^$'\n']+) ]]; then
      echo "Failed to save: ${BASH_REMATCH[1]}" >&2
      json="$(jq '.outputs += { error: $error }' --arg error "${BASH_REMATCH[1]}" <<< "$json")"
    fi
    for x in 'Cache saved with key' 'File Size' 'Cache Size' ; do
      if [[ $raw =~  $x:\ ([^$'\n']+) ]]; then
        # echo "x=$x y=${BASH_REMATCH[1]}" >&2
        json="$(jq '.outputs += ([{ key: $key, value: $value}]|from_entries)' --arg key "$x" --arg value "${BASH_REMATCH[1]}" <<< "$json")"
      fi
    done
    jq . <<< "$json"
    if [[ $(jq -r '.outputs["cache-hit"]' <<< "$json") == true ]]; then exit 0 ; else exit -1 ; fi

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
