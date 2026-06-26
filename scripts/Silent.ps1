# =====================================================================
#  Silent.ps1  --  Ustawia profil SILENT na MSI GE78HX (i9-13950HX)
#  przez oficjalny interfejs MSI WMI (root\wmi MSI_ACPI / Set_Data).
#  Dziala niezaleznie od wersji MSI Center (tez tej bez przycisku Silent).
#  Bez sterownikow, bez RW-Everything, bez dotykania blocklisty.
#  Odwracalne: uruchom Balanced.ps1.
#
#  Przepis zmierzony z MSI Center 2.0.48 (firmware EC 17S1IMS1.114):
#    0xD2=C1 (Comfort)  0x34=00  0xEB=00  0xD4=1D (fan Silent)
#  Kluczowy lewar = 0xD4=1D: firmware EC wiaze go z capem mocy (~30-40W).
#  (0x89/0x91 to czujniki obrotow wentylatorow, nie ustawienia - usuniete.)
# =====================================================================
$ErrorActionPreference = 'Stop'

# self-elevacja (UAC)
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

# przepis SILENT (kolejnosc wazna; crit = bajt decydujacy o cap mocy)
# 0x89/0x91 to czujniki obrotow wentylatorow (read-only), NIE ustawienia -> usuniete.
$recipe = @(
    @{ a = 0xD2; v = 0xC1; crit = $true },
    @{ a = 0x34; v = 0x00; crit = $true },
    @{ a = 0xEB; v = 0x00; crit = $true },
    @{ a = 0xD4; v = 0x1D; crit = $true }
)

foreach ($r in $recipe) { WriteEC ([byte]$r.a) ([byte]$r.v) }
Start-Sleep -Milliseconds 300

$ok = $true
Write-Host "`n  PROFIL: SILENT  (cichy, ~30-40 W)" -ForegroundColor Green
foreach ($r in $recipe) {
    $got = ReadEC ([byte]$r.a)
    $match = ($got -eq [byte]$r.v)
    if ($r.crit -and -not $match) { $ok = $false }
    $tag = if ($match) { '' } else { '  <- rozni sie (niekrytyczny)' }
    Write-Host ("    {0:X2} = {1:X2}  (cel {2:X2}){3}" -f $r.a, $got, $r.v, $tag)
}
if ($ok) { Write-Host "  OK - Silent zastosowany." -ForegroundColor Green }
else     { Write-Host "  UWAGA: krytyczny bajt nie przyjety - uruchom ponownie." -ForegroundColor Yellow }
Start-Sleep -Seconds 2
