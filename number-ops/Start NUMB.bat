@echo off
setlocal
set "SCRIPT=%~dp0NUMB.ahk"

if exist "%~dp0AutoHotkey64.exe" (
  start "" "%~dp0AutoHotkey64.exe" "%SCRIPT%"
  exit /b 0
)

where autohotkey64.exe >nul 2>&1
if %ERRORLEVEL%==0 (
  start "" autohotkey64.exe "%SCRIPT%"
  exit /b 0
)

where autohotkey.exe >nul 2>&1
if %ERRORLEVEL%==0 (
  start "" autohotkey.exe "%SCRIPT%"
  exit /b 0
)

if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" (
  start "" "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" "%SCRIPT%"
  exit /b 0
)

if exist "%ProgramFiles%\AutoHotkey\AutoHotkey64.exe" (
  start "" "%ProgramFiles%\AutoHotkey\AutoHotkey64.exe" "%SCRIPT%"
  exit /b 0
)

echo AutoHotkey v2 not found. Re-run the NUMB installer or install from https://www.autohotkey.com/
pause
exit /b 1
