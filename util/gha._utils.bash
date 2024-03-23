#!/bin/bash

gha-have-runtime()(test -v ACTIONS_RUNTIME_TOKEN && test -n "$ACTIONS_RUNTIME_TOKEN")

gha-err(){ echo $1 && echo "[gha-err rc=$1] $@" >&2 && exit $1 ; }

gha-esc()( printf "%q" "$@" )
gha-unesc()( eval "echo $@" )


# emit jq "entry" line given key and a raw json-encoded value
function gha-kv-raw() {
  local key="$1"
  shift
  jq -ncR --arg key "$key" --argjson value "$(echo "$@")" '{key:$key, value:$value}'
}


# emit jq "entry" line given key and string value
function gha-kv-json() {
  local key="$1"
  shift
  jq -ncR --arg key "$key" --arg value "$(echo "$@")" '{key:$key, value:$value}'
}

# loosely interpret actions-core stdout lines
# - demoting debug/info/notice to stderr
# - promoting ::warning:: and ::error:: into pseudo-outputs
function gha-stdmap() {
  local -n __Github="$1"

  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ::(debug|info|notice):: ]]; then
      echo "[${BASH_REMATCH[1]}] $line" | tee -a ${__Github[stderr]} >&2
    # note: ::set-output only emerges on stdout when GITHUB_OUTPUT is not specified
    elif [[ $line =~ ::(set-output) ]]; then
      local type=${BASH_REMATCH[1]}
      local line="${line/::$type /}"
      echo "[$type] $line" | tee -a ${__Github[stdout]} >&2
      if [[ $line =~ name=([^:]+)::(.*) ]]; then
        local name="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
        echo -e "$name<<ghadelimiter${type}\n$value\nghadelimiter${type}" >> ${__Github[GITHUB_OUTPUT]}
      fi
    elif [[ $line =~ ::(error|warning):: ]]; then
      local type=${BASH_REMATCH[1]}
      local line="${line/::$type::/}"
      echo "[$type] $line" | tee -a ${__Github[stdout]} >&2
      if [[ $type == warning ]]; then echo "$line" >> ${__Github[warnings]} ; fi
      if [[ $type == error ]]; then echo "$line" >> ${__Github[errors]} ; fi
      echo -e "${type}<<ghadelimiter${type}\n$line\nghadelimiter${type}" >> ${__Github[GITHUB_OUTPUT]}
    else
      echo "[stdout] $line"| tee -a ${__Github[stdout]} >&2
    fi
  done
}

# decode GITHUB_OUTPUT streamed '{key}<<{delimiter}\n{value}\n{delimiter}` values
# emits '{ "key": "{key}", value: "{value}" }' entries on stdout
function gha-capture-outputs() {
  local -n __buffer="$1"
  local key="" value="" delim="ghadelimiterNULL"
  while IFS= read -r line || [[ -n $line ]]; do
      if [[ $line == $delim ]]; then
        # __outputs[$key]="$value"
        gha-kv-json "$key" "$value"
        delim="" key="" value=""
      elif [[ $line =~ ^([-A-Za-z_]+)\<\<(ghadelimiter.*) ]]; then
          key=${BASH_REMATCH[1]}
          delim=${BASH_REMATCH[2]}
          value=""
      elif [[ -n $key && -n $line ]]; then
          value+="${line//$'\r'/}"
      else
        echo "[gha-capture-outputs] unexpected line='$line'" >&2
      fi
  done < "$__buffer"
}

# usage:
#  local -a Input=(...)
#  gha-check Input overwrite '(false|true)' || return 1
function gha-check() {
  local -n ref="$1"
  local name="$2"
  local expected="$3"
  if [[ " ${ref[@]} " =~ INPUT_${name}=${expected}\   ]]; then
    return 0
  else
    local actual="$(echo  "${ref[@]}" | grep -Eo "INPUT_${name}=[^ ]+")"
    echo -e "EXPECTED: \n\tINPUT_${name}=${expected}\nACTUAL:\n\t$actual" >&2
    echo "${ref[@]}" >&2
    return 70
  fi
}

# like above but trigges exit
function gha-assert() {
  gha-check "$@" || exit `gha-err 71 "{$1} $2 !=~ $3"`
}

# attempt to transform bash associative array to valid JSON structure...
function gha-assoc-to-json() {
  local -n __gha_assoc_map="$1"
  echo "$(
    declare -p $1 \
      | perl -pe "s@^declare [-Ax]+ $1=\\(@\n@; s@\\)\$@\\n@" \
      | perl -pe 's@\[([^\]]+)\]=@\n{ "key": "$1", "value": @g' \
      | perl -pe "$(cat <<'EOP'
        s@("value": )(.*)@my $a=$2; "$1".($a=~s/^\$'|'[\)\s]/\"/g,$a)."}"@ge
EOP
        )"
  )" | jq -c || return `gha-err 91 "gha-assoc-to-json failed '$1' ::: $(declare -p $1)"`

}

function gha-invoke-action() {(
    set -Euo pipefail

    # local script="$1"
    # shift

    local -a Invocation=("$@")
    declare -p Invocation >&2

    local -A Github=()
    local -a Env=()

    source $(dirname $BASH_SOURCE)/gha._mktemp.bash $BASHPID

    # capture GITHUB_XYZ writable streams
    for i in stdout stderr errors warnings GITHUB_OUTPUT GITHUB_ENV GITHUB_PATH GITHUB_STATE; do
      local tmpfile=$(gha-_mktemp $i)
      test -e "$tmpfile" || exit `gha-err $? "failed to create temp file..."`
      Github[$i]="$tmpfile"
      if [[ $i =~ ^GITHUB_ ]]; then Env+=("$i=$tmpfile") ; fi
    done

    # on Windows environment variables do not seem case-sensitive
    # actions/upload-artifact expects upper-case keys internally
    # upcase INPUT_<xyz> names and also collect input values for debug output
    local -A inputs=()
    for i in "${!Invocation[@]}"; do
      local input=$(grep -Eo '^INPUT_[^=]*' <<< "${Invocation[$i]}")
      if [[ -n "$input" ]] ; then
        Invocation[$i]=$(sed 's/^\(INPUT_[^=]*\)=/\U\1=/' <<< "${Invocation[$i]}")
        inputs[${input/INPUT_/}]="$(gha-unesc "$(grep -Eo '=.*' <<< "${Invocation[$i]}" | sed 's@^=@@')")"
      fi
    done

    local -a Eval=("${Env[@]}" "${Invocation[@]}")
    # declare -p Github >&2
    echo "----------------------------------------" >&2
    echo "env ${Eval[@]}" >&2
    echo "----------------------------------------" >&2

    eval "env ${Eval[@]}" | gha-stdmap Github >&2
    echo "----------------------------------------" >&2
    wait
    # { <outputs>, __streams__: { stdout, GITHUB_ENV, GITHUB_STATE, ... } }
    (
        gha-kv-raw inputs "$(gha-assoc-to-json inputs | jq -sc from_entries || echo null)"
        gha-kv-raw outputs "$(gha-capture-outputs Github[GITHUB_OUTPUT] | jq -sc from_entries || echo null)"
        gha-kv-raw data "$((
          gha-kv-json Invocation "${Invocation[@]}"
          for i in "${!Github[@]}"; do
             gha-kv-json $i "$(cat "${Github[$i]}" | tr -d '\r')"
          done
        ) | jq -Ss from_entries)"
    ) | jq -s from_entries
    # jq -s from_entries "$github_output"
    echo "----------------------------------------" >&2
)}

