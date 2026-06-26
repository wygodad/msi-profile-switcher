# =====================================================================
#  msi_ec_fulldump.ps1
#  CEL: pelny zrzut calego EC (256 bajtow) w kazdym scenariuszu MSI,
#       zeby porownac bajt-po-bajcie i znalezc WSZYSTKIE roznice
#       miedzy Silent a reszta (w tym ewentualny rejestr mocy).
#
#  BEZPIECZENSTWO: WYLACZNIE odczyt (Get_Data). Zero zapisu.
#  Oficjalny interfejs MSI WMI - bez sterownikow, bez blocklisty.
# =====================================================================

$ErrorActionPreference = 'Stop'

# --- self-elevacja ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Wymagane uprawnienia administratora - ponawiam z podniesieniem (UAC)..." -ForegroundColor Yellow
    $exe = (Get-Process -Id $PID).Path
    Start-Process $exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    return
}

$outFile = "D:\temp\Claude\msi_ec_fulldump.txt"
"=== MSI EC FULL DUMP  $(Get-Date)  (TYLKO ODCZYT) ===" | Out-File $outFile -Encoding utf8

$inst = Get-CimInstance -Namespace root\wmi -ClassName MSI_ACPI

# odczyt jednego bajtu EC: wejscie Bytes[0]=adres, wyjscie Bytes[1]=wartosc
function ReadEC([byte]$addr) {
    $b = New-Object byte[] 32
    $b[0] = $addr
    $pkg = New-CimInstance -Namespace root\wmi -ClassName Package_32 -ClientOnly -Property @{ Bytes = $b }
    $res = Invoke-CimMethod -InputObject $inst -MethodName Get_Data -Arguments @{ Data = $pkg }
    return $res.Data.Bytes[1]
}

# pelny zrzut 0x00..0xFF w siatce 16-kolumnowej
function DumpAll($label) {
    "" | Out-File $outFile -Append -Encoding utf8
    "[$label]" | Out-File $outFile -Append -Encoding utf8
    for ($row = 0; $row -lt 256; $row += 16) {
        $vals = for ($c = 0; $c -lt 16; $c++) { '{0:X2}' -f (ReadEC ([byte]($row + $c))) }
        ('{0:X2}: {1}' -f $row, ($vals -join ' ')) | Out-File $outFile -Append -Encoding utf8
    }
    Write-Host "  $label - zrzucone (256 bajtow)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "  TYLKO ODCZYT EC. NIC NIE ZAPISUJE." -ForegroundColor Green
Write-Host "  Przelaczaj scenariusz w MSI Center, potem Enter." -ForegroundColor Green
Write-Host ""

foreach ($s in 'SILENT', 'BALANCED', 'EXTREME PERFORMANCE', 'SUPER BATTERY') {
    [void](Read-Host ">> Ustaw w MSI Center: $s   -- potem nacisnij Enter")
    DumpAll $s
}

Write-Host ""
Write-Host "Gotowe. Wyniki zapisane w: $outFile" -ForegroundColor Green
[void](Read-Host "Nacisnij Enter aby zamknac")
