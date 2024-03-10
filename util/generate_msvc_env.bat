@echo off
REM calculates a bash-style native x86_64 VS2022 environment variable set to stdout 
bash -c 'declare -x' | sort > before

if exist "%VS170COMNTOOLS%" (
  set VS2022_COMMON_TOOLS=%VS170COMNTOOLS%
) else (
    set VS2022_ROOT=C:\Program Files\Microsoft Visual Studio\2022\Community

    if not exist "%VS2022_ROOT%" (
      set VS2022_ROOT=C:\Program Files\Microsoft Visual Studio\2022\Enterprise
    )
    if not exist "%VS2022_ROOT%" (
      echo could not find VS2022_ROOT
      exit 1
    )
    set VS2022_COMMON_TOOLS=%VS2022_ROOT%\Common7\Tools
)

call "%VS2022_COMMON_TOOLS%\VsDevCmd.bat" -arch=x64 -host_arch=x64 -no_logo
REM call C:\PROGRA~1\MICROS~2\2022\ENTERP~1\Common7\Tools\VsDevCmd.bat -arch=x64 -host_arch=x64 -no_logo

bash -c 'declare -x' |sort > after
bash -c "diff before after | grep '^[>]' | sed -e 's@^> @@'"
