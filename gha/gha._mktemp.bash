#!/bin/bash

# note: meant to be sourced inline within a subshell'd function() {( source gha.tmpfiles.bash ; ... )} scope

function gha_mktemp_cleanup_temp_files() {
    local tmpdir="$1" pid=$2
    ( test -n "$tmpdir" && test -d "$tmpdir" ) || { echo "!tmpdir=$tmpdir" >&2 ; exit 7 ; }
    echo "[gha_mktemp_cleanup_temp_files] '$tmpdir/*.$pid.gha_mktemp.*'" >&2
    for tmpfile in $tmpdir/*.$pid.gha_mktemp.* ; do
        rm -f "$tmpfile" >&2
    done
}
_gha_mktemp_pid=${1:-BASHPID}
_gha_mktemp_pid_tmpdir="$(dirname "$(mktemp -u -p "" --suffix=.$_gha_mktemp_pid.gha_mktemp.XXX)")"
( test -n "$_gha_mktemp_pid_tmpdir" && test -d "$_gha_mktemp_pid_tmpdir" ) || { echo "!tmpdir=$_gha_mktemp_pid_tmpdir" >&2 ; exit 7 ; }
trap "gha_mktemp_cleanup_temp_files '$_gha_mktemp_pid_tmpdir' '$_gha_mktemp_pid'" EXIT

echo _gha_mktemp_pid_tmpdir=$_gha_mktemp_pid_tmpdir
function gha-_mktemp() {(
    set -Euo pipefail
    local name=$1 pid=$_gha_mktemp_pid
    ( test -n "$_gha_mktemp_pid_tmpdir" && test -d "$_gha_mktemp_pid_tmpdir" ) || { echo "!tmpdir=$_gha_mktemp_pid_tmpdir" >&2 ; exit 7 ; }
    local tmpfile="$(mktemp -p "$_gha_mktemp_pid_tmpdir" --suffix=.$pid.gha_mktemp.$1)"
    echo "$tmpfile"
)}
