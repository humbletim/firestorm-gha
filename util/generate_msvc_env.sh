#!/bin/bash
#cmake_path=${cmake_path:-"$(dirname "$(which cmake.exe)")"}
#echo "cmake path: $cmake_path" >&2

test -s build/msvc.env || $gha_fsvr_dir/util/generate_msvc_env.bat > build/msvc.env
. build/msvc.env

msvc_path="$(
  $gha_fsvr_dir/util/_utils.sh reduce-paths "$msvc_env_PATH" \
    "/mingw64/bin:/usr/bin:/bin:/c/msys64/home/runneradmin/bin:$HOME/bin"
)"

echo "$msvc_path" > build/msvc_path.txt
declare -xp msvc_path | tee build/msvc_path.env

# calculate MSVR redistributable location
test -n "$VCToolsVersion" || _die "!VCToolsVersion"
test -d "$VCToolsRedistDir" || _die "!VCToolsRedistDir"
TOOLSVER=$(echo $VCToolsVersion | sed -e 's@^\([0-9]\+\)[.]\([0-9]\).*$@\1\2@')
CRT=$(cygpath -mas "$VCToolsRedistDir"/x64/Microsoft.VC*.CRT/)
test -d $CRT || { echo "msvc CRT '$CRT' does not exist" &>2 ; exit 20 ; }

{
  echo msvc_dir=$CRT
  for x in ninja_path cmake_path cl_path ; do
    if test -v $x ; then
      eval "${x}=\"\$(cygpath -ua \"${!x}\")\""
    fi
  done
  # cmake_path=$(cygpath -ua "$cmake_path")
  # test ! -v ninja_path || ninja_path=$(cygpath -ua "$ninja_path")
  export PATH="$ninja_path:$cmake_path:$msvc_path:$PATH:/usr/bin:/c/Windows/system32"
  echo "cmake : $PATH $(which cmake)" >&2
  cl_path="$(dirname "$(which cl.exe)")"
  PATH="$cl_path:$PATH"
  for x in cl lib link mt rc cmake ninja python3 cmcldeps; do
    y="$(which $x.exe)"
    test -x "$y" || { echo "could not locate $x '$y'" >&2 ; exit 26; }
    echo ${x}_exe=$(cygpath -msa "$y")
  done
  echo "cmd_exe=$(cygpath -wsa "${COMSPEC:-$(which cmd.exe)}")"
  echo 'python_exe=$python3_exe'
} | tee build/msvc.nunja.env
