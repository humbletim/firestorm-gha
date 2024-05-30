# bash helper that returns unit CPU load level [0.0-1.0]
# note: somewhat specific to github actions windows-2022 runner
# -- 2024.03.20 humbletim

function load-level() {
 /c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoLogo -Command "Get-Counter -Counter '\Processor(_Total)\% Processor Time'  -MaxSamples 1" 2>&1 | /usr/bin/xargs /usr/bin/echo | /usr/bin/grep -Eo '[^ ]+$'
}
