#!/bin/bash
#
# git-union-merge.sh
#
# A script to perform a targeted 3-way "union" merge on a single file. It can be
# run directly as a command-line tool or sourced into another script to provide
# the `git_union_merge` helper function.
#
# This is designed to preemptively resolve predictable, non-overlapping conflicts
# (like two branches adding an #include in the same general area) without leaving
# conflict markers. It's intended for ephemeral CI/CD environments where persistent
# git config changes are impractical.
#
# USAGE (as a command-line tool):
#   ./git-union-merge.sh <mod-branch> <file-path>
#
# USAGE (sourced in another script):
#   source ./git-union-merge.sh
#   git_union_merge <mod-branch> <file-path>
#

# Exit immediately if a command exits with a non-zero status.
# We set this within the function to avoid affecting the sourcing shell.

# --- Helper Function ---
# Encapsulates the core logic of the script.
git_union_merge() {
    # Use a subshell or set -e locally to avoid exiting the parent script on error
    (
        set -e

        # --- Argument Validation ---
        if [ "$#" -ne 2 ]; then
            echo "Usage: git_union_merge <mod-branch> <file-path>" >&2
            echo "Example: git_union_merge sidestream/sgeo_min_vr_7.1.9 indra/newview/llviewerdisplay.cpp" >&2
            return 1
        fi

        local MOD_BRANCH="$1"
        local FILE_PATH="$2"

        # --- Pre-flight Checks ---
        if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
            echo "Error: Not inside a Git repository." >&2
            return 1
        fi

        if [ ! -f "$FILE_PATH" ]; then
            echo "Error: File not found at path: ${FILE_PATH}" >&2
            return 1
        fi

        echo "-> Starting union merge for: ${FILE_PATH}" >&2

        # --- Define File Versions ---
        # OURS is the version currently on disk in the working directory.
        local UPSTREAM_BRANCH
        UPSTREAM_BRANCH=$(git rev-parse HEAD)
        local OURS_FILE="${FILE_PATH}"

        # --- Find Common Ancestor (BASE) ---
        echo "-> Finding common ancestor between HEAD (${UPSTREAM_BRANCH:0:7}) and ${MOD_BRANCH}..." >&2
        local MERGE_BASE_COMMIT
        MERGE_BASE_COMMIT=$(git merge-base "${UPSTREAM_BRANCH}" "${MOD_BRANCH}")

        if [ -z "$MERGE_BASE_COMMIT" ]; then
            echo "Error: Could not find a merge base between ${UPSTREAM_BRANCH} and ${MOD_BRANCH}." >&2
            return 1
        fi
        echo "-> Found common ancestor commit: ${MERGE_BASE_COMMIT:0:7}" >&2

        # --- Isolate File Versions into Temporary Files ---
        local BASE_FILE THEIRS_FILE MERGED_FILE
        BASE_FILE=$(mktemp)
        THEIRS_FILE=$(mktemp)
        MERGED_FILE=$(mktemp)
        # Set up a trap to ensure temporary files are cleaned up on exit, error, or interrupt.
        trap 'rm -f "${BASE_FILE}" "${THEIRS_FILE}" "${MERGED_FILE}"' RETURN

        echo "-> Extracting BASE and THEIRS versions to temporary files..." >&2
        git show "${MERGE_BASE_COMMIT}:${FILE_PATH}" > "${BASE_FILE}"
        git show "${MOD_BRANCH}:${FILE_PATH}" > "${THEIRS_FILE}"

        # --- Perform the Union Merge ---
        echo "-> Running 'git merge-file --union'..." >&2
        if git merge-file -p --union "${OURS_FILE}" "${BASE_FILE}" "${THEIRS_FILE}" > "${MERGED_FILE}"; then
            mv "${MERGED_FILE}" "${OURS_FILE}"
            echo "✅ Success! File '${FILE_PATH}' merged cleanly." >&2
        else
            echo "❌ Error: A hard conflict was detected in '${FILE_PATH}'. Manual resolution required." >&2
            echo "-> Conflicting output can be found in: ${MERGED_FILE}" >&2
            # Let the subshell exit with an error code.
            return 1
        fi
    )
}

# --- Script Entrypoint (like Python's `if __name__ == "__main__":`) ---
# This block only runs when the script is executed directly, not when sourced.
# It allows the script to be used as a standalone tool.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # When executed, call the main function with all command-line arguments.
    set -e
    git_union_merge "$@"
fi

