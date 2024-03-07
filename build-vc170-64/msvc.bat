@echo off
bash -c 'declare -x' | sort > before
call C:\\PROGRA~1\\MICROS~2\\2022\\ENTERP~1\\Common7\\Tools\\VsDevCmd.bat -arch=x64 -host_arch=x64 -no_logo
bash -c 'declare -x' |sort > after
bash -c "diff before after | grep '^[>]' | sed -e 's@^> @@' > msvc.env"
ls -lrth msvc.env >&2


