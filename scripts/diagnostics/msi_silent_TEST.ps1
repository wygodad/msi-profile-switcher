# =====================================================================
#  msi_silent_TEST.ps1   --- PIERWSZY ZAPIS (test, w pelni odwracalny) ---
#
#  Zapisuje DOKLADNIE te wartosci EC, ktore MSI Center sam ustawia dla
#  scenariusza SILENT (zmierzone w fulldump). Nic nie jest wymyslone.
#
#  BEZPIECZENSTWO:
#   - po kazdym zapisie czyta wartosc z powrotem; jesli nie przyjeta -> STOP
#   - dziala fazami z pauzami, zebys widzial efekt w ThrottleStop
#   - NA KONCU automatycznie przywraca wartosci BALANCED
#   - w razie czego: klik dowolnego profilu w MSI Center albo restart = powrot
#
#  Kanal: oficjalny MSI WMI (Set_Data / Get_Data). Bez sterownikow.
# =====================================================================

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $exe = (Get-Process -Id $PID).Path
    Start-Process $exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    return
}

$inst = Get-CimInstance -Namespace root\wmi -ClassName MSI_ACPI

function ReadEC([byte]$addr) {
    $b = New-Object byte[] 32; $b[0] = $addr
    $pkg = New-CimInstance -Namespace root\wmi -ClassName Package_32 -ClientOnly -Property @{ Bytes = $b }
    $res = Invoke-CimMethod -InputObject $inst -MethodName Get_Data -Arguments @{ Data = $pkg }
    return $res.Data.Bytes[1]
}
function WriteEC([byte]$addr, [byte]$val) {
    $b = New-Object byte[] 32; $b[0] = $addr; $b[1] = $val
    $pkg = New-CimInstance -Namespace root\wmi -ClassName Package_32 -ClientOnly -Property @{ Bytes = $b }
    [void](Invoke-CimMethod -InputObject $inst -MethodName Set_Data -Arguments @{ Data = $pkg })
}
function TryWrite([byte]$addr, [byte]$val) {
    $before = ReadEC $addr
    try { WriteEC $addr $val } catch { Write-Host ("  {0:X2}: BLAD ZAPISU -> {1}" -f $addr, $_.Exception.Message) -ForegroundColor Red; return $false }
    Start-Sleep -Milliseconds 400
    $after = ReadEC $addr
    $ok = ($after -eq $val)
    $col = if ($ok) { 'Green' } else { 'Red' }
    Write-Host ("  {0:X2}: przed={1:X2}  zapis={2:X2}  po={3:X2}  {4}" -f $addr, $before, $val, $after, $(if ($ok) { 'OK' } else { '!! NIE PRZYJETO' })) -ForegroundColor $col
    return $ok
}

Write-Host "`n=== TEST: odtworzenie SILENT przez zapis EC (odwracalny) ===" -ForegroundColor Cyan
Write-Host "Najpierw ustaw w MSI Center scenariusz BALANCED i miej otwarty ThrottleStop." -ForegroundColor Yellow
[void](Read-Host "Gdy jestes na BALANCED i widzisz ThrottleStop -> Enter")

$d4 = ReadEC 0xD4
if ($d4 -ne 0x0D) { Write-Host "UWAGA: 0xD4=$('{0:X2}' -f $d4), spodziewane 0D (Balanced). Mimo to kontynuuje." -ForegroundColor Yellow }

# ---- FAZA 1: fan mode = Silent (najbezpieczniejszy, znany rejestr) ----
Write-Host "`n[FAZA 1] fan mode -> Silent (0xD4=1D)" -ForegroundColor Cyan
if (-not (TryWrite 0xD4 0x1D)) {
    Write-Host "Zapis nie przeszedl. Przerywam, nic wiecej nie ruszam. Metoda/format do poprawy." -ForegroundColor Red
    [void](Read-Host "Enter aby zamknac"); return
}
Write-Host "Patrz na wentylatory (powinny zwolnic). PKG Power notuj." -ForegroundColor Yellow
[void](Read-Host "Po ~20s -> Enter (przejdziemy do bajtu mocy)")

# ---- FAZA 2: 0x34 = 00 (glowny podejrzany o cap mocy) ----
Write-Host "`n[FAZA 2] 0x34 -> 00 (podejrzany o limit mocy)" -ForegroundColor Cyan
[void](TryWrite 0x34 0x00)
Write-Host "TERAZ patrz na PKG Power w ThrottleStop pod lekkim obciazeniem." -ForegroundColor Yellow
Write-Host "Czy moc siada w okolice ~38 W?" -ForegroundColor Yellow
[void](Read-Host "Po ~30s -> Enter")

# ---- FAZA 3: 0x89=30, 0x91=50 (reszta przepisu Silent) ----
Write-Host "`n[FAZA 3] 0x89 -> 30 oraz 0x91 -> 50 (dopelnienie Silent)" -ForegroundColor Cyan
[void](TryWrite 0x89 0x30)
[void](TryWrite 0x91 0x50)
Write-Host "Pelny przepis Silent zapisany. Sprawdz PKG Power i halas." -ForegroundColor Yellow
[void](Read-Host "Po ~30s -> Enter aby PRZYWROCIC Balanced")

# ---- REVERT: wartosci Balanced ----
Write-Host "`n[PRZYWRACANIE] Balanced..." -ForegroundColor Cyan
[void](TryWrite 0xD4 0x0D)
[void](TryWrite 0x34 0x01)
[void](TryWrite 0x89 0x3C)
[void](TryWrite 0x91 0x5F)
Write-Host "`nPrzywrocono Balanced. (Dla pewnosci mozesz tez kliknac Balanced w MSI Center.)" -ForegroundColor Green
[void](Read-Host "Enter aby zamknac")
