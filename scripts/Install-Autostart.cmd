@echo off
where pwsh >nul 2>nul && (pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Autostart.ps1") || (powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Autostart.ps1")
pause
