#!/bin/bash
set -Euo pipefail
test -v GITHUB_ACTIONS || { echo "GITHUB_ACTIONS expected" >&2 ; exit 3 ; }
# /d/a/_actions/humbletim/firestorm-gha/tpv-gha-nunja
export gha_fsvr_dir=$(readlink -f $(dirname "${BASH_SOURCE}"))
export ghash=$gha_fsvr_dir/gha
source $ghash/gha.ht-ln.bash
ht-ln $gha_fsvr_dir/gha-node20-run ./fsvr-action

export PATH="$PATH:/c/ProgramData/Chocolatey/bin"
jq '.inputs.fstuple|fromjson' $GITHUB_EVENT_PATH \
  | jq -r 'to_entries[]|select(.value!="")|[.key,.value]|join("=")' \
  | tee -a $GITHUB_ENV

source $GITHUB_ENV
export workspace=${GITHUB_WORKSPACE:-${workspace:-$PWD}}

$gha_fsvr_dir/gha-generate-shell-env.sh | tee -a SHELL.env
