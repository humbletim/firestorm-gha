#!/bin/bash

gha_esc()( printf "%q" "$@" )
gha_err(){ echo $1 && echo "[gha_err rc=$1] $@" >&2 && exit $1 ; }

gha_capture_tag()( local TAG=$1 && shift && echo ">(${@:-sed 's@^@[$TAG] @'})" )
gha_capture()( local ENV=$1 && shift && echo "${ENV}=>(${@:-sed 's@^@[$ENV] @'})" )

function gha_kv_json() {
  jq -ncR --arg key "$1" --arg value "$2" '{key:$key, value:$value}'
}


function gha_stdmap() {
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ::(debug|warning|info|notice):: ]]; then
      echo "[${BASH_REMATCH[1]}] $line" >&2
    elif [[ $line =~ ::error:: ]]; then
      echo "[error] $line" >&2
      gha_kv_json "error" "$line" >> "${Github[OUTPUT]:-/dev/stdout}"
    else
      echo "[stdout] $line" >&2
    fi
  done
}


function gha_capture_outputs() {
  # local _outputs_file="${1:-/dev/stderr}"
  local key="" value="" delim="ghadelimiterNULL"
  local -A outputs
  while IFS= read -r line || [[ -n $line ]]; do
      # echo "[_capture_outputs] line='$line'" >&2
      if [[ $line == $delim ]]; then
        # echo "[OUTPUT] $key='$value'" >&2
        outputs[$key]="$value"
        gha_kv_json "$key" "$value"
        delim="" key="" value=""
      elif [[ $line =~ ^([-A-Za-z_]+)\<\<(ghadelimiter.*) ]]; then
          key=${BASH_REMATCH[1]}
          delim=${BASH_REMATCH[2]}
          value=""
      elif [[ -n $key && -n $line ]]; then
          value+="${line//$'\r'/}"
      else
        echo "[_capture_outputs] unexpected line='$line'" >&2
      fi
  done #>> "$_outputs_file"
}

function gha-invoke-action() {(
    set -Euo pipefail

    # local script="$1"
    # shift

    local -a Invocation=("$@")
    declare -p Invocation >&2

    local -A Github=()
    local -a Env=()
    for i in OUTPUT ENV PATH STATE; do
      local tmpfile="$(mktemp -p "" --suffix=GITHUB_$i.ghadata)"
      trap "rm -f $tmpfile >&2" EXIT
      Github[$i]="$tmpfile"
      Env+=("GITHUB_$i=$tmpfile")
    done

    # on Windows environment variables do not seem case-sensitive
    # actions/upload-artifact expects upper-case keys internally
    # to make Linux testable this upper-cases all the input keys
    for i in "${!Invocation[@]}"; do
      Invocation[$i]=$(sed 's/^\(INPUT_[^=]*\)=/\U\1=/' <<< "${Invocation[$i]}")
    done

    local -a Eval=("${Env[@]}" "${Invocation[@]}")
    declare -p Github >&2
    echo "----------------------------------------" >&2
    echo "env ${Eval[@]}" >&2
    echo "----------------------------------------" >&2

    test -v ACTIONS_RUNTIME_TOKEN || return `gha_err 81 "ACTIONS_RUNTIME_TOKEN missing"`

    eval "env ${Eval[@]}" | gha_stdmap >&2
    echo "----------------------------------------" >&2
    wait
    for i in "${!Github[@]}"; do
      echo "$i [[[ $(cat "${Github[$i]}") ]]]" >&2
    done
    cat "${Github[OUTPUT]}" | gha_capture_outputs | jq -s from_entries
    # jq -s from_entries "$github_output"
    echo "----------------------------------------" >&2
)}

