@echo off
setlocal DisableDelayedExpansion
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Modkit.ps1" %*
set "result=%errorlevel%"
if not "%result%"=="0" (
  echo.
  echo Modkit install reported failures. See sandbox\log\modkit.log
  if "%~1"=="" pause
  exit /b %result%
)
echo.
echo Modkit command completed.
if "%~1"=="" pause
exit /b %result%
