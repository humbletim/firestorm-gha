#!/bin/bash

function make-stub() {(
  CC=${CC:-'/c/Program Files/LLVM/bin/clang'}
  # CC=${CC:-'/c/mingw64/bin/gcc'}
  set -x
  local here=$(dirname "$BASH_SOURCE")
  # [[ $OSTYPE == msys ]] && BASH=$(cygpath -mas $BASH)
  "${CC}" -w "-DBASH=\"$(printf "%q" "$BASH")\"" \
    $here/BASH_FUNC_invoke.c -o "${1:-bin/BASH_FUNC_invoke.exe}"
)}

function make-echo-exe() {(
  local output="$1" message="$2"
  # CC=${CC:-'/c/mingw64/bin/gcc'}
  CC=${CC:-'/c/Program Files/LLVM/bin/clang'}
  set -x
  echo '
     #include <stdio.h>
     #include <io.h>
     extern int _setmode(int, int);
     #define _O_BINARY 0x8000
     //#include <fnctl.h>
     int main(int argc, char *argv[]) { _setmode(1,_O_BINARY); printf("%s\n", MESSAGE); return 0; }
   ' | "${CC}" -w "-DMESSAGE=\"$(printf "%s" "$message")\"" -x c - -o "$output" || return $?
  ls -l "$output"
)}

# function alias-exe() {
#   local name=$1
#   shift
#  #  (
#  #    # echo "function _alias_exe_tmp() { $@ ; }"
#  #    # eval "function _alias_exe_tmp() { $@ ; }"
#  #    # declare -xf _alias_exe_tmp
#  #    # printf "BASH_FUNC_${name}=%q\n" "$(declare -pf _alias_exe_tmp | sed "s@_alias_exe_tmp ()@function ${name} ()@;s@_alias_exe_tmp@${name}@;s@^declare .*@@")"
#  #    #$(fsvr/util/_utils.sh __getenv 'BASH_FUNC__alias_exe_tmp%%')"
#  #    #     # echo --------------------------
#  #    # local body="$(fsvr/util/_utils.sh __getenv 'BASH_FUNC__alias_exe_tmp%%' | sed 's@^() @@')"
#  #    # body="$(echo "$body" | jq -sR | sed 's@[$]@\\$@g;' )"
#  #    # body="$(echo "$body" | sed -e 's@\\n\"@\"@g;' )"
#  #    # echo "BASH_FUNC_${name}=${body}" | command -p tee -a $GITHUB_ENV
#  #    # echo --------------------------
#  # )
#   # declare -xf ${name} ; declare -fp ${name} ; env | grep ${name}" | command -p tee -a $GITHUB_ENV
#   # echo "BASH_FUNC_${name}()($@)" | command -p tee -a $GITHUB_ENV
#   fsvr/util/_utils.sh ht-ln bin/BASH_FUNC_invoke.exe bin/$name.exe
# }
