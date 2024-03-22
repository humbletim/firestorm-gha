#!/bin/bash

test -s build/msvc.env || fsvr/util/generate_msvc_env.bat > build/msvc.env
. build/msvc.env

msvc_path="$(
  fsvr/util/_utils.sh reduce-paths "$msvc_env_PATH" \
    "/mingw64/bin:/usr/bin:/bin:/c/msys64/home/runneradmin/bin:$HOME/bin"
)"

echo "$msvc_path" > build/msvc_path.txt
declare -xp msvc_path | tee build/msvc_path.env

# calculate MSVR redistributable location
test -n "$VCToolsVersion" || _die "!VCToolsVersion"
test -d "$VCToolsRedistDir" || _die "!VCToolsRedistDir"
TOOLSVER=$(echo $VCToolsVersion | sed -e 's@^\([0-9]\+\)[.]\([0-9]\).*$@\1\2@')
CRT=$(cygpath -mas "$VCToolsRedistDir/x64/Microsoft.VC$TOOLSVER.CRT/")
test -d $CRT || { echo "msvc CRT '$CRT' does not exist" &>2 ; return 20 ; }

{
  echo msvc_dir=$CRT
  PATH="$msvc_path:$PATH:/usr/bin:/c/Windows/system32"
  for x in cl lib link mt rc cmake ninja python cmcldeps; do
    echo ${x}_exe=$(cygpath -msa "$(which $x.exe)")
  done
  echo "cmd_exe=$(cygpath -wsa "$(which $x.exe)")"
} | tee build/msvc.nunja.env
