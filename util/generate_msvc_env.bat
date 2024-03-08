@echo off
REM calculates a bash-style native x86_64 VS2022 environment variable set to stdout 
bash -c 'declare -x' | sort > before
call C:\\PROGRA~1\\MICROS~2\\2022\\ENTERP~1\\Common7\\Tools\\VsDevCmd.bat -arch=x64 -host_arch=x64 -no_logo
bash -c 'declare -x' |sort > after
bash -c "diff before after | grep '^[>]' | sed -e 's@^> @@'"
