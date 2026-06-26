# =====================================================================
#  Install-Autostart.ps1
#  Tworzy zadanie Harmonogramu, ktore uruchamia MSI-Hotkeys.ps1 przy
#  KAZDYM logowaniu, z najwyzszymi uprawnieniami (BEZ UAC) i ukryte.
#  Dzieki temu skroty dzialaja od razu po starcie systemu.
#
#  Odinstalowanie:
#    Unregister-ScheduledTask -TaskName 'MSI Profile Hotkeys' -Confirm:$false
# =====================================================================
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process (Get-Process -Id $PID).Path -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    return
}

$ps1 = Join-Path $PSScriptRoot 'MSI-Hotkeys.ps1'
if (-not (Test-Path $ps1)) { Write-Host "Brak MSI-Hotkeys.ps1 obok tego pliku." -ForegroundColor Red; Read-Host 'Enter'; return }

$exe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $exe) { $exe = (Get-Command powershell).Source }

$taskName  = 'MSI Profile Hotkeys'
$action    = New-ScheduledTaskAction -Execute $exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ps1`""
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "OK - autostart zainstalowany i uruchomiony." -ForegroundColor Green
Write-Host "Skroty: Ctrl+Alt+F1..F4 oraz Ctrl+Alt+P (cykl). Ikona w zasobniku." -ForegroundColor Green
Start-Sleep -Seconds 3
