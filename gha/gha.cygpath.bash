#!/bin/bash

if ! cygpath . >/dev/null 2>/dev/null ; then
  test ! -v DEBUG || echo "[$BASH_SOURCE] emulating cygpath $OSTYPE 1=$1 2=$2" >&2
  function cygpath() {
    case "$1" in
      -pm) echo "'$1' / -pm not yet implemented... '$2'" >&2 ; return 89 ;;
      -ua) shift ; readlink -f "$1" ;;
      -*p*) echo "'$1' / -p not yet implemented... '$2'" >&2 ; return 90 ;;
      -*a*) shift ; readlink -f "$1" ;;
      -*m*) shift ; readlink -m "$1" ;;
      -*) echo "'$1' not yet implemented... '$2'" >&2 ; return 99 ;;
      *) readlink "$1" ;;
    esac
  }
fi
