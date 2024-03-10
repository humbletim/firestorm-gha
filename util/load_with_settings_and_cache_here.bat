REM launch firestorm with os-level settings and cache locations
REM --humbletim 2024.03.08
REM %~dp0 == path of this batch file
REM %* forwards any arguments alonge; eg:
REM   launch_with_settings_and_cache_here.bat --set UIScaleFactor 1

REM new Firestorm_x64 user settings location

set "APPDATA=%~dp0"

REM new FirestormOS_x64 cache/temp location

set "LOCALAPPDATA=%~dp0"

REM actual .exe name to launch
REM use an absolute path unless in same folder as this batch file

call $APPLICATION_EXE %*
