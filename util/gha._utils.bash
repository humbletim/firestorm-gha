#!/bin/bash

gha-have-runtime()(test -v ACTIONS_RUNTIME_TOKEN && test -n "$ACTIONS_RUNTIME_TOKEN")

gha-err(){ echo $1 && echo "[gha-err rc=$1] $@" >&2 && exit $1 ; }

gha_die='{ echo "[gha-die rc=$1] $@" ; exit $1 ; }'

gha-esc()( printf "%q" "$@" )
gha-unesc()( eval "echo $@" )


function gha-action-stderr-filter() {
  sed -u "s@^@|$FUNCNAME| @" | grep --line-buffered -Ei "\\b(jq|error): |\[(gha-.*?|warning|error)\]" >&2
}

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
  local stream=$1 # stdout | stderr
  local N=1
  [[ $stream == stderr ]] && N=2;
  local -n __Github=$2
  local line=""
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ::(debug|info|notice):: ]]; then
      local type=${BASH_REMATCH[1]}
      local line="${line/::$type::/}"
      echo "[$type] $line" | tee -a ${__Github[$stream]} >&$N
    # note: ::set-output only emerges on stdout when GITHUB_OUTPUT is not specified
    elif [[ $line =~ ::(set-output) ]]; then
      local type=${BASH_REMATCH[1]}
      local line="${line/::$type /}"
      echo "[$type] $line" | tee -a ${__Github[$stream]} >&$N
      if [[ $line =~ name=([^:]+)::(.*) ]]; then
        local name="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
        echo -e "$name<<ghadelimiter${type}\n$value\nghadelimiter${type}" >> ${__Github[GITHUB_OUTPUT]}
      fi
    elif [[ $line =~ ::(error|warning):: ]]; then
      local type=${BASH_REMATCH[1]}
      local line="${line/::$type::/}"
      echo "[$type] $line" | tee -a ${__Github[$stream]} >&$N
      if [[ $type == warning ]]; then echo "$line" >> ${__Github[warnings]} ; fi
      if [[ $type == error ]]; then echo "$line" >> ${__Github[errors]} ; fi
      echo -e "${type}<<ghadelimiter${type}\n$line\nghadelimiter${type}" >> ${__Github[GITHUB_OUTPUT]}
    else
      echo "[$stream] $line"| tee -a ${__Github[$stream]} >&$N
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

# convert a JSON structure to flattened bash associatiave array
# { nested: { keys: ...} } become [nested:keys]=...
function gha-json-to-assoc() {
    # local array=$1 key=$2 json=$@
    local json="$3"
    # ensure special chars do not disrupt jq/shell interpretations
    json="$(perl -pe '
      s@\\([\\\"\x27 ])@sprintf("~__u%04x__~", (ord($1)))@ge;
      s@\\u0000@{nul}@g;
      s@\\n@~__u000a__~@g;
      s@\\r@~__u000d__~@g;
      s@\\t@~__u0009__~@g;
    ' <<< "$json")"
    _gha-json-to-assoc $1 "$2" "$json"
}

function _gha-json-to-assoc() {
    local -n _assoc=$1
    local paths="$2"
    local json="$3"
    local JSON
    JSON="$(echo -n "$json" | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]")"
    test $? -eq 0 || { echo "error --- $?" ; echo "json=$json" ; exit 99;  }

    local kv
    while read -r kv; do
        [ -z "$kv" ] && break
        local path='' key value
        IFS== read key value <<< "$kv"
        [ -z "$paths" ] || key="$paths:$key"
        if [[ $value =~ ^\{.*\}$  || $value =~ ^\[.*\]$ ]]; then
            _gha-json-to-assoc $1 "$key" "$value"
        else
            value="$(perl -pe 's@~__u(....)__~@chr(hex("0x$1"))@ge' <<< "$value")"
            _assoc[$key]="$value"
        fi
    done <<< "$JSON"

  #| wc -l  #echo
}


# [nested:keys] become { nested: { keys: ... }}
function gha-assoc-to-flatjson() {
  local -n __gha_assoc_map="$1"
  local flat
  (
    local x y comma=
    echo '{'
    for x in "${!__gha_assoc_map[@]}"; do
      local y="${__gha_assoc_map[$x]}"
      cat << EOJ
       $comma "$x": $(echo -n "$y" | jq -Rs | tr -d '\r')
EOJ
      comma=,
    done
    echo '}'
  ) | jq -S
}


# attempt to transform bash associative array to JSON structure
# [nested:keys] become { nested: { keys: ... }}
# usage: gha-assoc-to-json <arrayref> [prefix ...]
#  -- if prefixes specified, filters to "^(prefix|prefix2):"
function gha-assoc-to-json() {
  local mapname=$1
  shift
  if [[ -n "$@" ]] ; then
    local regex="^($(echo "$@" | tr ' ' '|'))(:|\$)"
    # echo "regexp=$regex" >&2
    local -n __gha_input_map=$mapname
    local -A filtered_array=([.filter]=$regex)
    local -A excluded
    # Filter the array, excluding items whose keys start with the letter "k"
    for key in "${!__gha_input_map[@]}"; do
        if [[ $key =~ $regex ]]; then
            filtered_array[$key]="${__gha_input_map[$key]}"
        else
            excluded["${key%%:*}"]=1
        fi
    done
    filtered_array[".excluded"]="${!excluded[@]}"
  else
      local -n filtered_array=$mapname
  fi

  local flat
  flat="$(gha-assoc-to-flatjson filtered_array)"
  local jqsrc
  jqsrc="$(jq -rS '
    to_entries |
    map( .value as $value |
         .key  | split(":") |
        "."+([.[]|[.]|tojson]|join("")+"="+($value|tojson))
    ) | join(" |\n")
  ' <<< "$flat" )"
  jq -n "$jqsrc"
}

# gha-match-text-entries <textmapref> <outputref> [text ...]
function gha-match-text-entries() {
  local -n _textmap=$1
  local -n _found=$2
  shift 2
  local raw="$@$'\n'"
  for x in "${!_textmap[@]}"; do
    local y="${_textmap[$x]}"
    if [[ $raw =~ $y([^$'\n']+)$'\n' ]]; then
       # echo "x='$x' y='$y' z='${BASH_REMATCH[1]}'" >&2
      _found[$x]="${BASH_REMATCH[1]}"
    fi
  done
}


function gha-jq-upsert-assoc() {
  local -n _buffer=$1
  local -n _assoc=$2
  local jqcmd="$3"
  local _fragment
  _fragment="$(gha-assoc-to-json $2)"
  local buffer
  buffer="$(jq --argjson assoc "$_fragment" "$jqcmd" <<< "$_buffer")" || return `gha-err $? "$FUNCNAME error $?"`
  _buffer="$buffer"
}


# gha-merge-arrays <firstref> <secondref>
function gha-merge-arrays() {
  local -n _first=$1
  local -n _second=$2
  eval "_first=( ${_first[*]@K} ${_second[*]@K} )"
}

function gha-invoke-action() {
    local -A __Raw
    local -n _Input=$1
    local -n _Command=$2
    local haveRaw=${3:-}
    local -n _Raw=${3:-__Raw}


    local -a Invocation=("${_Input[@]}" "${_Command[@]}")
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

    if [[ -v gha_invoke_action_test_json_file ]] ; then
      echo "using $gha_invoke_action_test_json_file" >&2
      local rc=$?
      local jsoninputs="$(jq .inputs $gha_invoke_action_test_json_file)"
      local jsonoutputs="$(jq .outputs $gha_invoke_action_test_json_file)"
      local jsondata="$(jq .data $gha_invoke_action_test_json_file)"
      local rc=0
    else
      { eval "echo tostderr test >&2 ; env ${Eval[@]}" 1> >(gha-stdmap stdout Github) 2> >(gha-stdmap stderr Github) ; } \
        2>&1 | gha-action-stderr-filter
      local rc=$?
      if [[ $rc -ne 0 ]] ; then
        echo -e "error<<ghadelimiterx\nexit code: $rc\nghadelimiterx" >> ${Github[GITHUB_OUTPUT]}
      fi
      local jsoninputs="$(gha-assoc-to-flatjson inputs || echo null)";
      local jsonoutputs="$(gha-capture-outputs Github[GITHUB_OUTPUT] | jq -sc from_entries || echo null)"
      local jsondata="$((
            gha-kv-json Invocation "${Invocation[@]}"
            for i in "${!Github[@]}"; do
               gha-kv-json $i "$(cat "${Github[$i]}" | tr -d '\r')"
            done
          ) | jq -Ss from_entries)"
    fi
    echo "-----$rc-----------------------------------" >&2
    wait

    local json
    json="$(jq -n '{ $inputs, $outputs, $data, $rc }' \
      --argjson inputs "$jsoninputs" \
      --argjson outputs "$jsonoutputs" \
      --argjson data "$jsondata" \
      --argjson rc "$rc" )"
    if [[ $? -ne 0 ]]; then
      if jq -e . <<< "$jsoninputs" >/dev/null; then echo "jsoninputs OK" ; else "jsoninputs bad '$jsoninputs'" ; fi
      if jq -e . <<< "$jsonoutputs" >/dev/null; then echo "jsonoutputs OK" ; else "jsonoutputs bad '$jsonoutputs'" ; fi
      if jq -e . <<< "$jsondata" >/dev/null; then echo "jsondata OK" ; else "jsondata bad '$jsondata'" ; fi
      jq -e . <<< "$rc" >/dev/null && echo "rc OK"
      exit 12345
    fi

    if [[ -n $haveRaw ]] ; then
      gha-json-to-assoc _Raw "" "$json"
    else
      jq -S <<< "$json"
    fi
    # gha-assoc-to-flatjson _Raw "" "$json"

    echo "----------------------------------------" >&2
}

