#!/bin/bash
test -d "${1}" || { echo "$0 expected builddir as first and only script argument" ; exit 1; } 
set -eu
sleep 2 && touch ${1}/packages/cmake_tracking/sentinel_installed || true
sleep 2 && touch `ls ${1}/packages/cmake_tracking/*_installed | fgrep -v sentinel_installed` || true
