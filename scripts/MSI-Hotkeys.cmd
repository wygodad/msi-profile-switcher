@echo off
REM Uruchamia przelacznik profili w tle (ukryte okno). PS sam poprosi o UAC.
where pwsh >nul 2>nul && (start "" pwsh -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0MSI-Hotkeys.ps1") || (start "" powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0MSI-Hotkeys.ps1")
