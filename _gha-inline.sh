#!/bin/bash
set -Euo pipefail
test -v GITHUB_ACTIONS || { echo "GITHUB_ACTIONS expected" >&2 ; exit 3 ; }
# /d/a/_actions/humbletim/firestorm-gha/tpv-gha-nunja
export gha_fsvr_dir=$(readlink -f $(dirname "${BASH_SOURCE}"))
export ghash=$gha_fsvr_dir/gha

export PATH="$PATH:/c/ProgramData/Chocolatey/bin"
if [[ -v GITHUB_EVENT_PATH ]]; then
  jq '.inputs.fstuple|fromjson' $GITHUB_EVENT_PATH \
    | jq -r 'to_entries[]|select(.value!="")|[.key,.value]|join("=")' \
    | tee -a $GITHUB_ENV
else
  mkdir -pv env.d
  {
     echo base=$base
     echo repo=local
     echo ref=local
     echo root_dir=$PWD
     test ! -v nunja_dir || echo nunja_dir=$nunja_dir
  } | tee -a $GITHUB_ENV env.d/local.env
fi
source $GITHUB_ENV
export workspace=${GITHUB_WORKSPACE:-${workspace:-$PWD}}
