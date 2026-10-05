@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\OEM\install.ps1 >> C:\OEM\install.log 2>&1
exit /b %errorlevel%
