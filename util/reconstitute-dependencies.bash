#!/bin/bash

function _parallel() {( set -Euo pipefail;
    test -d "$build_dir" || return 7
    local funcname=$1
    shift
    test -f $build_dir/$funcname.txt && rm -v $build_dir/$funcname.txt
    # declare -f parallel >/dev/null || return `_err $? "parallel() not defined"`;
    parallel --joblog $build_dir/$funcname.txt --halt-on-error 2 "$@" \
      || { rc=$? ; echo "see $build_dir/$funcname.txt" >&2 ; return $rc ; }
)}

function _verify_one() {( set -Euo pipefail;
    # echo "_verify_one $@"
    local name=$1 hash=$2 filename=$(basename "$3")
    local tool=md5sum
    test "$(echo -n "$hash"|wc -c)" == "40" && tool=sha1sum
    echo "$hash $filename" > $filename.$tool
    #echo "$tool: $filename ($fsvr_cache_dir)" >&2

    local got=
    got=($($tool $filename))
    out="$($tool --strict --check $filename.$tool)" || {
        rc=$?
        echo "$out"
        echo "checksum failed: $filename expected: $hash got: ${got:-}" >&2 ;
        return $rc
    }
    type -t _relativize >/dev/null && _relativize "$out"
    return 0
)}


function download_packages() {( set -Euo pipefail;
    local packages_json="$1" cache_dir="$2"
    test -d "$cache_dir" || return 36
    echo packages_json=$packages_json >&2
    echo cache_dir=$cache_dir >&2
    export cache_dir
    jq -r '.[]|.url' $packages_json | grep http \
      | _parallel "$FUNCNAME" -j4 'set -e ; echo {} >&2 ; wget -nv -N -P "$cache_dir" -N {} ; test -s "$cache_dir/$(basename {})" ; exit 0'
)}

function verify_downloads() {( set -Euo pipefail;
    local packages_json="$1" cache_dir="$2"
    test -d "$cache_dir"    || return 46
    echo packages_json=$packages_json >&2
    echo cache_dir=$cache_dir >&2
    cd $cache_dir
    jq -r '.[]|"name="+.name+" hash="+.hash+" url="+(.url//"null")' $packages_json | grep -v url=null \
      | sed -e 's@ url=[^ ]\+/@ url=@' \
      | self="${BASH_SOURCE}" _parallel "$FUNCNAME" -j4 '{} ; $self _verify_one $name $hash $(basename $url)' \
      || _die "verification failed $?"
    return 0
)}

function untar_packages() {( set -Euo pipefail;
    local packages_json="$1" cache_dir="$2" packages_dir="$3"
    test -d "$packages_dir" || return 61
    test -d "$cache_dir"    || return 62
    echo packages_dir=$packages_dir >&2
    echo cache_dir=$cache_dir >&2
    export cache_dir
    cd $packages_dir
    jq -r '.[]|.url' $packages_json | grep -vE '^null$' \
      | _parallel "$FUNCNAME" -j8 'basename {} && tar --exclude=autobuild-package.xml --force-local -xf "$cache_dir/$(basename {})"' \
      || _die "untar failed $?"
)}
