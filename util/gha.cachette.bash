#!/bin/bash

# bash gha helper for saving and restoring caches
# depends on workflow-level `uses: actions/cache@v4` and running within a node20/ACTIONS_RUNTIME_TOKEN enabled context
# -- 2023.03.22 humbletim

source $(dirname $BASH_SOURCE)/gha._utils.bash

# key, path, restore-keys, upload-chunk-size, enableCrossOsArchive, fail-on-cache-miss, lookup-only

function cache-exists() {(
    set -Euo pipefail

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_cache_dir="${actions_cache_dir:-/d/a/_actions/actions/cache/v4}"
    local script="${script:-${actions_cache_dir}/dist/restore-only/index.js}"

    local -a Input=(
        INPUT_key="`gha-esc "$1"`"
        INPUT_path="`gha-esc "$2"`"
        INPUT_lookup-only=true
        INPUT_fail-on-cache-miss=ignore
    )
    local -a Output=(
        cache-hit
        cache-primary-key
        cache-matched-key
    )
    local -a State=(
      CACHE_KEY
      CACHE_RESULT
    )
    local -a Command=(
      `gha-esc "$node"`
      `gha-esc "$script"`
    )

    gha-invoke-action "${Input[@]}" "${Command[@]}"
)}

function restore-only() {(
    set -Euo pipefail

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_cache_dir="${actions_cache_dir:-/d/a/_actions/actions/cache/v4}"
    local script="${script:-${actions_cache_dir}/dist/restore-only/index.js}"

    local -a Input=(
        INPUT_key="`gha-esc "$1"`"
        INPUT_path="`gha-esc "$2"`"
        # INPUT_restore-keys=
        # INPUT_fail-on-cache-miss=error
    )
    local -a Output=(
        cache-hit
        cache-primary-key
        cache-matched-key
    )
    local -a State=(
      CACHE_KEY
      CACHE_RESULT
    )

    local -a Command=(
      `gha-esc "$node"`
      `gha-esc "$script"`
    )

    gha-invoke-action "${Input[@]}" "${Command[@]}"
)}

function save-only() {(
    set -Euo pipefail

    local PATH="$PATH:/usr/bin"
    local node="${node:-/c/Program Files/nodejs/node}"
    local actions_cache_dir="${actions_cache_dir:-/d/a/_actions/actions/cache/v4}"
    local script="${script:-${actions_cache_dir}/dist/save-only/index.js}"

    local -a Input=(
        INPUT_key="`gha-esc "$1"`"
        INPUT_path="`gha-esc "$2"`"
    )
    local -a Output=(
        cache-hit
        cache-primary-key
        cache-matched-key
    )
    local -a State=(
      CACHE_KEY
      CACHE_RESULT
    )

    local -a Command=(
      `gha-esc "$node"`
      `gha-esc "$script"`
    )

    gha-invoke-action "${Input[@]}" "${Command[@]}"
)}
