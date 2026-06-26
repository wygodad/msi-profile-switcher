# =====================================================================
#  Set-MsiProfile.ps1 -Mode <Silent|Balanced|Extreme|SuperBattery>
#
#  Ustawia wybrany profil MSI przez oficjalny interfejs MSI WMI
#  (root\wmi MSI_ACPI / Set_Data). Uzywane przez MSI-Profiles.ahk.
#  Self-elevacja (UAC) gdy uruchomione bez admina.
#
#  Wypisuje na koniec jedna linie:  RESULT=<Mode>
# =====================================================================
param(
    [Parameter(Mandatory)]
    [ValidateSet('Silent', 'Balanced', 'Extreme', 'SuperBattery')]
    [string]$Mode
)
$ErrorActionPreference = 'Stop'

# self-elevacja z zachowaniem -Mode
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process (Get-Process -Id $PID).Path -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode"
    return
}

$inst = Get-CimInstance -Namespace root\wmi -ClassName MSI_ACPI
function WriteEC([byte]$a, [byte]$v) {
    $b = New-Object byte[] 32; $b[0] = $a; $b[1] = $v
    $pkg = New-CimInstance -Namespace root\wmi -ClassName Package_32 -ClientOnly -Property @{ Bytes = $b }
    [void](Invoke-CimMethod -InputObject $inst -MethodName Set_Data -Arguments @{ Data = $pkg })
}

# Przepisy. 0xD4 to lewar mocy; 0xEB pilnuje super-battery.
# 0x89/0x91 to czujniki obrotow wentylatorow (read-only), NIE ustawienia -> usuniete.
$recipes = @{
    Silent       = @(@{a=0xD2;v=0xC1}, @{a=0x34;v=0x00}, @{a=0xEB;v=0x00}, @{a=0xD4;v=0x1D})
    Balanced     = @(@{a=0xD2;v=0xC1}, @{a=0x34;v=0x01}, @{a=0xEB;v=0x00}, @{a=0xD4;v=0x0D})
    Extreme      = @(@{a=0xD2;v=0xC4}, @{a=0x34;v=0x01}, @{a=0xEB;v=0x00}, @{a=0xD4;v=0x0D})
    SuperBattery = @(@{a=0xD2;v=0xC2}, @{a=0x34;v=0x01}, @{a=0xEB;v=0x0F}, @{a=0xD4;v=0x0D})
}

foreach ($r in $recipes[$Mode]) { WriteEC ([byte]$r.a) ([byte]$r.v) }
Write-Output "RESULT=$Mode"
