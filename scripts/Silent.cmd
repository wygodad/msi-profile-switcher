@echo off
where pwsh >nul 2>nul && (pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Silent.ps1") || (powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Silent.ps1")
