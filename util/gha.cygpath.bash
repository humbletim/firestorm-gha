#!/bin/bash

if ! cygpath . >/dev/null 2>/dev/null ; then
  test ! -v DEBUG || echo "[$BASH_SOURCE] emulating cygpath $OSTYPE" >&2
  function cygpath() {
    case "$1" in
      -*p*) echo "'$1' / -p not yet implemented..." >&2 ; exit 89 ;;
      -*a*) shift ; readlink -f "$1" ;;
      -*) shift ; readlink -m "$1" ;;
      *) readlink "$1" ;;
    esac
  }
fi
