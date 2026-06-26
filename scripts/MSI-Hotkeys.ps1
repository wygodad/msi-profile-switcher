# =====================================================================
#  MSI-Hotkeys.ps1  --  Przelacznik profili MSI GE78HX w tle
#
#  - globalne skroty klawiszowe przelaczaja profil
#  - ladne OSD na ekranie pokazuje aktualny tryb (jak "mouse remap: on")
#  - ikona w zasobniku (tray) z menu i wyjsciem
#  - zapis przez oficjalny interfejs MSI WMI (Set_Data), bez sterownikow
#
#  SKROTY (mozna zmienic nizej w sekcji $Hotkeys):
#     Ctrl+Alt+F1 = Silent        Ctrl+Alt+F3 = Extreme
#     Ctrl+Alt+F2 = Balanced      Ctrl+Alt+F4 = Super Battery
#     Ctrl+Alt+P  = cykl (Silent -> Balanced -> Extreme -> Super Battery)
# =====================================================================
$ErrorActionPreference = 'Stop'

# ---- self-elevacja (zapis EC wymaga admina) ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process (Get-Process -Id $PID).Path -Verb RunAs `
        -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Native {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# ====================== KONFIG: profile ==============================
# recipe: 0xD4 to lewar mocy. 0x89/0x91 to czujniki (usuniete). color/sub: OSD.
$Profiles = [ordered]@{
    Silent       = @{ label='SILENT';        sub='cicho · ~30-40 W';     color='#1FB58F';
                      recipe=@(@{a=0xD2;v=0xC1},@{a=0x34;v=0x00},@{a=0xEB;v=0x00},@{a=0xD4;v=0x1D}) }
    Balanced     = @{ label='BALANCED';      sub='pelna moc';            color='#2D7FF0';
                      recipe=@(@{a=0xD2;v=0xC1},@{a=0x34;v=0x01},@{a=0xEB;v=0x00},@{a=0xD4;v=0x0D}) }
    Extreme      = @{ label='EXTREME';       sub='maks · glosno';        color='#E0533D';
                      recipe=@(@{a=0xD2;v=0xC4},@{a=0x34;v=0x01},@{a=0xEB;v=0x00},@{a=0xD4;v=0x0D}) }
    SuperBattery = @{ label='SUPER BATTERY'; sub='oszczedzanie · ~15 W'; color='#3FB950';
                      recipe=@(@{a=0xD2;v=0xC2},@{a=0x34;v=0x01},@{a=0xEB;v=0x0F},@{a=0xD4;v=0x0D}) }
}
$Order = @('Silent','Balanced','Extreme','SuperBattery')

# ====================== KONFIG: skroty ==============================
# vks = lista kodow wirtualnych klawiszy (wszystkie wcisniete = wyzwolenie)
# Ctrl=0x11 Alt=0x12 Shift=0x10 ; F1=0x70 F2=0x71 F3=0x72 F4=0x73 ; P=0x50
$Hotkeys = @(
    @{ action='Silent';       vks=@(0x11,0x12,0x70) },
    @{ action='Balanced';     vks=@(0x11,0x12,0x71) },
    @{ action='Extreme';      vks=@(0x11,0x12,0x72) },
    @{ action='SuperBattery'; vks=@(0x11,0x12,0x73) },
    @{ action='__CYCLE__';    vks=@(0x11,0x12,0x50) }
)
# ====================================================================

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
function Get-CurrentMode {
    try {
        if ((ReadEC 0xD4) -eq 0x1D) { return 'Silent' }
        switch (ReadEC 0xD2) { 0xC4 { 'Extreme' } 0xC2 { 'SuperBattery' } default { 'Balanced' } }
    } catch { 'Balanced' }
}

# ---------------------- OSD (nakladka na ekranie) -------------------
$osd = New-Object System.Windows.Forms.Form
$osd.FormBorderStyle = 'None'; $osd.StartPosition = 'Manual'; $osd.TopMost = $true
$osd.ShowInTaskbar = $false; $osd.Size = New-Object System.Drawing.Size(430, 96)
$osd.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#16181D')
$osd.Opacity = 0.96
$accent = New-Object System.Windows.Forms.Panel
$accent.Dock = 'Left'; $accent.Width = 8; $osd.Controls.Add($accent)
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.AutoSize = $true; $lblTitle.Location = New-Object System.Drawing.Point(30, 16)
$lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = 'White'; $lblTitle.BackColor = 'Transparent'; $osd.Controls.Add($lblTitle)
$lblSub = New-Object System.Windows.Forms.Label
$lblSub.AutoSize = $true; $lblSub.Location = New-Object System.Drawing.Point(32, 58)
$lblSub.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$lblSub.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#9AA0AA'); $lblSub.BackColor = 'Transparent'
$osd.Controls.Add($lblSub)
$null = $osd.Handle  # wymus utworzenie uchwytu (pokazujemy przez ShowWindow bez aktywacji)

$hideTimer = New-Object System.Windows.Forms.Timer
$hideTimer.Interval = 1700
$hideTimer.Add_Tick({ $hideTimer.Stop(); [Native]::ShowWindow($osd.Handle, 0) | Out-Null })

function Show-Osd($mode) {
    $p = $Profiles[$mode]
    $accent.BackColor = [System.Drawing.ColorTranslator]::FromHtml($p.color)
    $lblTitle.Text = "MSI  ·  " + $p.label
    $lblSub.Text = $p.sub
    $scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $osd.Location = New-Object System.Drawing.Point(([int](($scr.Width - $osd.Width) / 2) + $scr.X), ($scr.Y + 90))
    [Native]::ShowWindow($osd.Handle, 8) | Out-Null   # SW_SHOWNA = pokaz bez kradziezy fokusa
    $hideTimer.Stop(); $hideTimer.Start()
}

# ---------------------- zastosowanie profilu -----------------------
$script:current = Get-CurrentMode
function Apply-Mode($mode) {
    try {
        foreach ($r in $Profiles[$mode].recipe) { WriteEC ([byte]$r.a) ([byte]$r.v) }
        $script:current = $mode
        Show-Osd $mode
        $notify.Text = "MSI Profile: " + $Profiles[$mode].label
    } catch {
        $lblTitle.Text = "MSI  ·  BLAD"; $lblSub.Text = $_.Exception.Message
        $accent.BackColor = 'Red'; [Native]::ShowWindow($osd.Handle, 8) | Out-Null
        $hideTimer.Stop(); $hideTimer.Start()
    }
}
function Cycle-Mode {
    $i = [Array]::IndexOf($Order, $script:current)
    Apply-Mode $Order[($i + 1) % $Order.Count]
}

# ---------------------- tray (zasobnik) ----------------------------
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
$notify.Text = "MSI Profile: " + $Profiles[$script:current].label
$menu = New-Object System.Windows.Forms.ContextMenuStrip
foreach ($m in $Order) {
    $item = $menu.Items.Add($Profiles[$m].label)
    $item.Tag = $m
    $item.Add_Click({ Apply-Mode $this.Tag }.GetNewClosure())
}
$null = $menu.Items.Add('-')
$exit = $menu.Items.Add('Zamknij')
$exit.Add_Click({ $notify.Visible = $false; $hideTimer.Stop(); [System.Windows.Forms.Application]::Exit() })
$notify.ContextMenuStrip = $menu
$notify.Add_MouseClick({ if ($_.Button -eq 'Left') { Cycle-Mode } })   # lewy klik = cykl

# ---------------------- petla skrotow ------------------------------
$script:hkDown = @{}
$poll = New-Object System.Windows.Forms.Timer
$poll.Interval = 60
$poll.Add_Tick({
    foreach ($hk in $Hotkeys) {
        $allDown = $true
        foreach ($vk in $hk.vks) { if (([Native]::GetAsyncKeyState($vk) -band 0x8000) -eq 0) { $allDown = $false; break } }
        $key = $hk.action
        if ($allDown -and -not $script:hkDown[$key]) {
            $script:hkDown[$key] = $true
            if ($key -eq '__CYCLE__') { Cycle-Mode } else { Apply-Mode $key }
        } elseif (-not $allDown) {
            $script:hkDown[$key] = $false
        }
    }
})
$poll.Start()

# powitalne OSD
Show-Osd $script:current

[System.Windows.Forms.Application]::Run((New-Object System.Windows.Forms.ApplicationContext))
$notify.Dispose()
