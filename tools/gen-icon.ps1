# Generuje app.ico (wielorozmiarowy, PNG-embedded) + preview.png
Add-Type -AssemblyName System.Drawing

function New-IconBitmap([int]$S) {
    $bmp = New-Object System.Drawing.Bitmap $S, $S
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # squircle tlo z gradientem teal -> blue
    $m = [Math]::Max(1, [int]($S * 0.07))
    $rect = New-Object System.Drawing.Rectangle $m, $m, ($S - 2*$m), ($S - 2*$m)
    $rad = [int]($S * 0.24)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $rad * 2
    $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()

    $c1 = [System.Drawing.ColorTranslator]::FromHtml('#35D6A8')
    $c2 = [System.Drawing.ColorTranslator]::FromHtml('#2D7FF0')
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c1, $c2, 55.0
    $g.FillPath($br, $path)

    # delikatny polysk u gory
    $gloss = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(60,255,255,255)), ([System.Drawing.Color]::FromArgb(0,255,255,255)), 90.0
    $g.FillPath($gloss, $path)

    # gauge (tachometr) - bialy luk + igla
    $cx = $S/2.0; $cy = $S/2.0 + $S*0.03
    $r  = $S * 0.27
    $penW = [Math]::Max(1.5, $S * 0.085)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(235,255,255,255)), $penW
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    $arcRect = New-Object System.Drawing.RectangleF (($cx-$r), ($cy-$r), (2*$r), (2*$r))
    $g.DrawArc($pen, $arcRect, 135, 270)

    # igla
    $ang = 215.0 * [Math]::PI / 180.0   # wskazuje w gore-lewo (umiarkowanie)
    $nx = $cx + [Math]::Cos($ang) * $r * 0.82
    $ny = $cy + [Math]::Sin($ang) * $r * 0.82
    $penN = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([Math]::Max(1.5, $S*0.06))
    $penN.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penN.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($penN, [single]$cx, [single]$cy, [single]$nx, [single]$ny)
    # srodek
    $dotR = $S*0.05
    $g.FillEllipse([System.Drawing.Brushes]::White, [single]($cx-$dotR), [single]($cy-$dotR), [single]($dotR*2), [single]($dotR*2))

    $g.Dispose()
    return $bmp
}

$dir = Split-Path -Parent $PSScriptRoot
$icoPath = Join-Path $dir 'app.ico'
$pngPath = Join-Path $PSScriptRoot 'preview.png'

# preview 256
$prev = New-IconBitmap 256
$prev.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)

# zbuduj ICO z PNG-ow (Vista+)
$sizes = 16,24,32,48,64,128,256
$pngs = @()
foreach ($s in $sizes) {
    $b = New-IconBitmap $s
    $ms = New-Object System.IO.MemoryStream
    $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += ,@($s, $ms.ToArray())
    $b.Dispose()
}
$fs = New-Object System.IO.FileStream $icoPath, ([System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter $fs
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$pngs.Count)  # ICONDIR
$offset = 6 + 16 * $pngs.Count
foreach ($p in $pngs) {
    $s = $p[0]; $data = $p[1]
    $bw.Write([byte]($(if ($s -ge 256) {0} else {$s})))   # width
    $bw.Write([byte]($(if ($s -ge 256) {0} else {$s})))   # height
    $bw.Write([byte]0); $bw.Write([byte]0)                 # colors, reserved
    $bw.Write([UInt16]1); $bw.Write([UInt16]32)            # planes, bpp
    $bw.Write([UInt32]$data.Length)
    $bw.Write([UInt32]$offset)
    $offset += $data.Length
}
foreach ($p in $pngs) { $bw.Write($p[1]) }
$bw.Flush(); $fs.Close()
Write-Output "ICO:  $icoPath"
Write-Output "PNG:  $pngPath"