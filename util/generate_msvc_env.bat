@echo off
REM calculates a bash-style native x86_64 VS2022 environment variable set to stdout
bash -c 'declare -x' | sort > before


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

@echo on
echo "%VS2022_COMMON_TOOLS%"\VsDevCmd.bat -arch=x64 -host_arch=x64 -no_logo >&2
call "%VS2022_COMMON_TOOLS%"\VsDevCmd.bat -arch=x64 -host_arch=x64 -no_logo >&2
REM call C:\PROGRA~1\MICROS~2\2022\ENTERP~1\Common7\Tools\VsDevCmd.bat -arch=x64 -host_arch=x64 -no_logo
@echo off

bash -c 'declare -x' |sort > after
bash -c "diff before after | grep '^[>]' | sed -e 's@^> @@'"

exit 0
