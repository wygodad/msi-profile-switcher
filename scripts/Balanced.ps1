# =====================================================================
#  Balanced.ps1  --  Przywraca profil BALANCED na MSI GE78HX
#  przez MSI WMI (root\wmi MSI_ACPI / Set_Data). Odwrotnosc Silent.ps1.
#
#  Przepis: 0xD2=C1  0x34=01  0xEB=00  0xD4=0D (fan Auto)
#  KOLEJNOSC jak w Silent: fan mode (0xD4) przed punktami krzywej.
# =====================================================================
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process (Get-Process -Id $PID).Path -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    return
}

$inst = Get-CimInstance -Namespace root\wmi -ClassName MSI_ACPI
function WriteEC([byte]$a, [byte]$v) {
    $b = New-Object byte[] 32; $b[0] = $a; $b[1] = $v
    $pkg = New-CimInstance -Namespace root\wmi -ClassName Package_32 -ClientOnly -Property @{ Bytes = $b }
    [void](Invoke-CimMethod -InputObject $inst -MethodName Set_Data -Arguments @{ Data = $pkg })
}
function ReadEC([byte]$a) {
    $b = New-Object byte[] 32; $b[0] = $a
    $pkg = New-CimInstance -Namespace root\wmi -ClassName Package_32 -ClientOnly -Property @{ Bytes = $b }
    return (Invoke-CimMethod -InputObject $inst -MethodName Get_Data -Arguments @{ Data = $pkg }).Data.Bytes[1]
}

$recipe = @(
    @{ a = 0xD2; v = 0xC1 },
    @{ a = 0x34; v = 0x01 },
    @{ a = 0xEB; v = 0x00 },
    @{ a = 0xD4; v = 0x0D }
)

foreach ($r in $recipe) { WriteEC ([byte]$r.a) ([byte]$r.v) }
Start-Sleep -Milliseconds 300

Write-Host "`n  PROFIL: BALANCED  (pelna moc)" -ForegroundColor Cyan
foreach ($r in $recipe) { Write-Host ("    {0:X2} = {1:X2}" -f $r.a, (ReadEC ([byte]$r.a))) }
Start-Sleep -Seconds 2
