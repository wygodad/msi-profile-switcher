# =====================================================================
#  msi_ec_snapshot.ps1
#  CEL: odczytac (TYLKO ODCZYT) wartosci rejestrow EC w kazdym
#       scenariuszu MSI Center, zeby ustalic "przepis na Silent".
#
#  BEZPIECZENSTWO: skrypt uzywa WYLACZNIE metody Get_Data (odczyt).
#  Nie ma tu zadnego Set_* / zapisu. Nic nie zmienia w systemie.
#  Uzywa oficjalnego interfejsu MSI WMI (root\wmi MSI_ACPI) -
#  bez sterownikow, bez RW-Everything, bez dotykania blocklisty.
# =====================================================================

$ErrorActionPreference = 'Stop'

# --- self-elevacja: jesli nie admin, uruchom ponownie z podniesieniem ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Wymagane uprawnienia administratora - ponawiam z podniesieniem (UAC)..." -ForegroundColor Yellow
    $exe = (Get-Process -Id $PID).Path
    Start-Process $exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    return
}

$outFile = "D:\temp\Claude\msi_ec_results.txt"
"=== MSI EC snapshot  $(Get-Date)  (TYLKO ODCZYT) ===" | Out-File $outFile -Encoding utf8

# --- instancja interfejsu MSI WMI ---
$inst = Get-CimInstance -Namespace root\wmi -ClassName MSI_ACPI

# --- funkcja: odczyt jednego bajtu EC pod podanym adresem ---
#     wejscie  Bytes[0] = adres
#     wyjscie  Bytes[0] = 01 (flaga OK), Bytes[1] = odczytana wartosc
function ReadEC([byte]$addr) {
    $b = New-Object byte[] 32
    $b[0] = $addr
    $pkg = New-CimInstance -Namespace root\wmi -ClassName Package_32 -ClientOnly -Property @{ Bytes = $b }
    $res = Invoke-CimMethod -InputObject $inst -MethodName Get_Data -Arguments @{ Data = $pkg }
    return $res.Data.Bytes[1]
}

# --- adresy wg msi-ec dla firmware 17S1IMS1.114 (blok CONF_G2_10) ---
#     0xD2 = Shift Mode, 0xD4 = Fan Mode, 0xEB = Super Battery, 0x98 = Cooler Boost
$addrs = [byte[]](0xD2, 0xD4, 0xEB, 0x98)

function Snapshot($label) {
    $line = ("[{0,-20}] " -f $label) + (($addrs | ForEach-Object {
        '{0:X2}={1:X2}' -f $_, (ReadEC $_)
    }) -join '   ')
    Write-Host $line -ForegroundColor Cyan
    $line | Out-File $outFile -Append -Encoding utf8
}

Write-Host ""
Write-Host "  TO JEST TYLKO ODCZYT EC. NIC NIE ZAPISUJE." -ForegroundColor Green
Write-Host "  Przelaczaj scenariusz w MSI Center, potem Enter." -ForegroundColor Green
Write-Host ""

foreach ($s in 'SILENT', 'BALANCED', 'EXTREME PERFORMANCE', 'SUPER BATTERY') {
    [void](Read-Host ">> Ustaw w MSI Center: $s   -- potem nacisnij Enter")
    Snapshot $s
}

Write-Host ""
Write-Host "Gotowe. Wyniki zapisane w: $outFile" -ForegroundColor Green
[void](Read-Host "Nacisnij Enter aby zamknac")
