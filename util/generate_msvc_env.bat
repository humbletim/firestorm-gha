@echo off
REM calculates a bash-style native x86_64 VS2022 environment variable set to stdout

set BASH_ENV=

bash -c 'declare -x |sort | sed "s@ PATH=@ msvc_env_PATH=@"' > before

if exist "%VS170COMNTOOLS%" (
  set "VS2022_COMMON_TOOLS=%VS170COMNTOOLS%"
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise" (
  set "VS2022_COMMON_TOOLS=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools"
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Community" (
  set "VS2022_COMMON_TOOLS=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools"
) else (
    echo "Could not locate VS170COMNTOOLS" >&2
    exit 170
)

echo "%VS2022_COMMON_TOOLS%"\VsDevCmd.bat -arch=x64 -host_arch=x64 -no_logo >&2
call "%VS2022_COMMON_TOOLS%"\VsDevCmd.bat -arch=x64 -host_arch=x64 -no_logo >&2

bash -c 'declare -x PATH="$($fsvr_dir/util/_utils.sh subtract_paths "$PATH" "/mingw64/bin:/usr/bin:/c/msys64/home/runneradmin/bin")"; declare -x |sort | sed "s@ PATH=@ msvc_env_PATH=@"' > after

bash -c 'paths="$(for x in cl rc; do dirname "$(which $x.exe)"; done | tr "\n" ":")"; paths="$($fsvr_dir/util/_utils.sh subtract_paths "$paths" "/bin:/usr/bin:/mingw64/bin:/mingw64/usr/bin:/usr/local/bin")" ; export msvc_path="$(cygpath -p "$paths")"; declare -xp msvc_path' | tee -a after > build/msvc_path.env

bash -c '. build/msvc_path.env ; export PATH="$msvc_path:/usr/bin"; for x in cl lib link mt rc; do echo ${x}_exe=$(cygpath -msa "$(which $x.exe)"); done' | tee build/msvc.nunja.env

bash -c "diff before after | grep '^[>]' | sed -e 's@^> @@'"

exit 0
