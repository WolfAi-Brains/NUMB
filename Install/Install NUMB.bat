@echo off
setlocal
cd /d "%~dp0"
echo NUMB installer — per-user install, no administrator required.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-NUMB.ps1" -StartWithWindows -LaunchNow
if errorlevel 1 (
  echo.
  echo Install failed. See messages above.
  pause
  exit /b 1
)
echo.
echo Done.
pause
