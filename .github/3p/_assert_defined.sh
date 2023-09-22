#!/bin/bash

function assert_defined() {
  local x=
  for x in $* ; do
    test -n "${!x:-}" || { echo "environment variable '$x' missing" ; exit 1 ; }
    if [[ -n "${DEBUG:-}" ]] ; then echo $x=${!x} >&2 ; fi
  done
}
