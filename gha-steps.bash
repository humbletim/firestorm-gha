#!/bin/bash

function gha_steps() {(
  local workflow=${workflow:-${workspace:-$(dirname "$BASH_SOURCE")}/.github/workflows/${GITHUB_WORKFLOW:-CompileWindows}.yml}
  PATH=$PATH:bin
  yaml2json < $workflow | jq -r '.jobs[].steps|to_entries[]|select(.value.name and ((.value.name//"")|startswith("~")|not))|.value.name+" # "+(.key|tostring)'
)}

function gha_step() {(
  local workflow=${workflow:-${workspace:-$(dirname "$BASH_SOURCE")}/.github/workflows/${GITHUB_WORKFLOW:-CompileWindows}.yml}
  PATH=$PATH:bin
  if [[ $# == 0 ]] ; then
    gha_steps
    return
  fi
  if [[ "$1" =~ ^[0-9a-f][0-9a-f][0-9a-f]$ ]]; then
    yaml2json < $workflow | jq -r --arg prefix "$1" '.jobs[].steps[]|select((.name//"")|startswith($prefix))|"# "+.name+"\n"+(.with.run//.run)'
  elif [[ "$1" =~ ^[0-9]+$ ]]; then
    yaml2json < $workflow | jq -r --argjson name "$1" '.jobs[].steps[$name]|"# "+.name+"\n"+(.with.run//.run)'
  else
    yaml2json < $workflow | jq -r --arg name "$1" '.jobs[].steps[]|select(.name==$name)|"# "+.name+"\n"+(.with.run//.run)'
  fi
)}
