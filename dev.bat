@echo off
REM Pass-through args (e.g. -- --portable). Use -Force to allow a second dev watcher.
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0dev.ps1" %*
if errorlevel 1 pause
