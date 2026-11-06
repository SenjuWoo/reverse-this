@echo off
rem Dry-run by default. Use: maintain.cmd -Apply, -UpdateTools, -Test or -All.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Maintain.ps1" %*
exit /b %errorlevel%
