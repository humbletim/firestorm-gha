#!/bin/bash
#set -Euo pipefail

function get_bootstrap_vars() {(
  set -Euo pipefail
  [[ -x /usr/bin/readlink ]] && pwd=`/usr/bin/readlink -f "$PWD"` || pwd=$PWD
  if [[ -v GITHUB_ACTIONS ]] ; then
      echo "[gha-bootstrap] GITHUB_ACTIONS=$GITHUB_ACTIONS" >&2
  else
      echo "[gha-bootstrap] local dev testing mode" >&2
  fi

  case "$OSTYPE" in
      msys|cygwin) viewer_os=windows ;;
      *)           viewer_os=linux   ;;
  esac

  echo _home=`readlink -f "${USERPROFILE:-$HOME}"`
  echo _bash=$BASH

  case "$base" in
    sl-*) viewer_name=SecondLife     ;;
    fs-*) viewer_name=Firestorm      ;;
    bd-*) viewer_name=BlackDragon    ;;
    al-*) viewer_name=Alchemy        ;;
  sgeo-*) viewer_name=Sgeo viewer_bin=firestorm ;;
  test-*) viewer_name=Test viewer_bin=firestorm ;;
       *) viewer_name=Unknown        ;;
  esac
  viewer_id=${viewer_id:-$(echo "$viewer_name" | tr '[:upper:]' '[:lower:]' | sed -e 's@[^-_A-Za-z0-9]@_@g')}

  echo viewer_os=$viewer_os
  echo viewer_id=$viewer_id
  echo viewer_name=$viewer_name
  echo viewer_bin=${viewer_bin:-$viewer_id}

  function to-id() { cat | sed 's@[^-a-zA-Z0-9_.]@-@g' ; }
  echo cache_id=$(echo "$base-$repo" | to-id)
  echo build_id=$(echo "${build_id:-$base}" | to-id)

  echo nunja_dir=`$gha_fsvr_dir/util/_utils.sh _realpath ${nunja_dir:-$fsvr_dir/$base}`
  echo fsvr_cache_dir=${fsvr_cache_dir:-$pwd/cache}

)}

function gha_steps() {
  local fsvr_dir=$(dirname $BASH_SOURCE)
  PATH=$PATH:bin
  yaml2json < $fsvr_dir/.github/workflows/CompileWindows.yml | jq -r '.jobs[].steps|to_entries[]|select(.value.name and ((.value.name//"")|startswith("~")|not))|.value.name+" # "+(.key|tostring)'
}

function gha_step() {
  local fsvr_dir=$(dirname $BASH_SOURCE)
  PATH=$PATH:bin
  if [[ "$1" =~ ^[0-9a-f][0-9a-f][0-9a-f]$ ]]; then
    yaml2json < $fsvr_dir/.github/workflows/CompileWindows.yml | jq -r --arg prefix "$1" '.jobs[].steps[]|select((.name//"")|startswith($prefix))|"# "+.name+"\n"+(.with.run//.run)'
  elif [[ "$1" =~ ^[0-9]+$ ]]; then
    yaml2json < $fsvr_dir/.github/workflows/CompileWindows.yml | jq -r --argjson name "$1" '.jobs[].steps[$name]|"# "+.name+"\n"+(.with.run//.run)'
  else
    yaml2json < $fsvr_dir/.github/workflows/CompileWindows.yml | jq -r --arg name "$1" '.jobs[].steps[]|select(.name==$name)|"# "+.name+"\n"+(.with.run//.run)'
  fi
}
