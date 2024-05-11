#!/bin/bash
set -Euo pipefail
test -v GITHUB_ACTIONS || { echo "GITHUB_ACTIONS expected" >&2 ; exit 3 ; } 
# /d/a/_actions/humbletim/firestorm-gha/tpv-gha-nunja
export gha_fsvr_dir=$(dirname "${BASH_SOURCE}") 
export fsvr_dir=${1:-$PWD/fsvr}
source $gha_fsvr_dir/util/gha.ht-ln.bash
ht-ln $gha_fsvr_dir $fsvr_dir
ht-ln $fsvr_dir/actions-node-script ./fsvr-action

export PATH="$PATH:/c/ProgramData/Chocolatey/bin"
echo '${{ inputs.fstuple }}' | jq -r 'to_entries[]|[.key,.value]|join("=")' | tee -a $GITHUB_ENV

export workspace=${GITHUB_WORKSPACE:-${workspace:-$PWD}}
function to-id() { cat | sed 's@[^-a-zA-Z0-9_.]@-@g' ; }

mkdir -pv env.d bin bin/pystuff cache repo build

echo cache_id=$(echo "$base-$repo" | to-id) | tee -a env.d/gha-bootstrap.env

$fsvr_dir/gha-generate-shell-env.sh | tee -a SHELL.env
