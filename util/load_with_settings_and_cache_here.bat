@echo off
REM | launch viewer with in-folder APPDATA (user settings) LOCALAPPDATA (cache, logs, etc.)
REM | ... for FS this will emerge ./Firestorm_x64 and ./FirestormOS_x64 respectively 
REM | --humbletim 2024.03.08
REM |
REM | %* forwards any arguments alonge; eg:
REM |  launch_with_settings_and_cache_here.bat --set UIScaleFactor 1
REM | %~dp0 == path of this batch file

set "APPDATA=%~dp0"
set "LOCALAPPDATA=%~dp0"
echo APPDATA=%APPDATA% LOCALAPPDATA=%LOCALAPPDATA%
call %~dp0\$APPLICATION_EXE %*
