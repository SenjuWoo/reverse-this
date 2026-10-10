@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Modkit.ps1" %*
if errorlevel 1 (
  echo.
  echo Modkit install reported failures. See sandbox\log\modkit.log
  pause
  exit /b 1
)
echo.
echo Modkit ready. Point an agent at this folder.
echo Tools: sandbox\bin
pause
