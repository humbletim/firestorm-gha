#!/bin/bash

function make-stub() {
  CC=${CC:-'/c/Program Files/LLVM/bin/clang'}
  #'-DDEBUG_COMMAND_STRING' 
  "${CC}" '-DBASH="c:/PROGRA~1/Git/usr/bin/bash.exe"' \
    fsvr/bashland/BASH_FUNC_invoke.c -o "${1:-bin/BASH_FUNC_invoke.exe}"
}

function alias-exe() {
  local name=$1
  shift
 #  (
 #    # echo "function _alias_exe_tmp() { $@ ; }"
 #    # eval "function _alias_exe_tmp() { $@ ; }"
 #    # declare -xf _alias_exe_tmp
 #    # printf "BASH_FUNC_${name}=%q\n" "$(declare -pf _alias_exe_tmp | sed "s@_alias_exe_tmp ()@function ${name} ()@;s@_alias_exe_tmp@${name}@;s@^declare .*@@")"
 #    #$(fsvr/util/_utils.sh __getenv 'BASH_FUNC__alias_exe_tmp%%')"
 #    #     # echo --------------------------
 #    # local body="$(fsvr/util/_utils.sh __getenv 'BASH_FUNC__alias_exe_tmp%%' | sed 's@^() @@')"
 #    # body="$(echo "$body" | jq -sR | sed 's@[$]@\\$@g;' )"
 #    # body="$(echo "$body" | sed -e 's@\\n\"@\"@g;' )"
 #    # echo "BASH_FUNC_${name}=${body}" | command -p tee -a $GITHUB_ENV 
 #    # echo --------------------------
 # ) 
  # declare -xf ${name} ; declare -fp ${name} ; env | grep ${name}" | command -p tee -a $GITHUB_ENV
  # echo "BASH_FUNC_${name}()($@)" | command -p tee -a $GITHUB_ENV
  fsvr/util/_utils.sh ht-ln bin/BASH_FUNC_invoke.exe bin/$name.exe
}          
