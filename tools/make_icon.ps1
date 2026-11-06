param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$crestPath = Join-Path $root 'assets\crests\crest_0.png'
if (-not (Test-Path $crestPath)) { throw "Wappen fehlt: $crestPath" }

function C([int]$r, [int]$g, [int]$b, [int]$a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

function New-Icon([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (C 36 25 16), (C 10 8 7), 90)
    $g.FillRectangle($bg, $rect)
    $bg.Dispose()
    $cx = $size / 2.0
    for ($i = 0; $i -lt 24; $i++) {
        $a = $i * [Math]::PI / 12.0
        $x1 = $cx + [Math]::Cos($a) * ($size * 0.18)
        $y1 = $cx + [Math]::Sin($a) * ($size * 0.18)
        $x2 = $cx + [Math]::Cos($a) * ($size * 0.52)
        $y2 = $cx + [Math]::Sin($a) * ($size * 0.52)
        $g.DrawLine((New-Object System.Drawing.Pen((C 208 164 82 18), 2)), [single]$x1, [single]$y1, [single]$x2, [single]$y2)
    }
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 196 150 78), [Math]::Max(3, $size / 90))), 10, 10, $size - 20, $size - 20)
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 92 63 32), [Math]::Max(1, $size / 220))), 22, 22, $size - 44, $size - 44)
    $crest = [System.Drawing.Image]::FromFile($crestPath)
    $w = [int]($size * 0.56)
    $h = [int]($w * 1.2)
    $g.DrawImage($crest, [int](($size - $w) / 2), [int]($size * 0.18), $w, $h)
    $crest.Dispose()
    for ($k = 0; $k -lt 4; $k++) {
        $x = if (($k % 2) -eq 0) { 22 } else { $size - 22 }
        $y = if ($k -lt 2) { 22 } else { $size - 22 }
        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 66 44 22))), $x - 7, $y - 7, 14, 14)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 220 176 94))), $x - 3, $y - 3, 6, 6)
    }
    $g.Dispose()
    return $bmp
}

$big = New-Icon 512
$big.Save((Join-Path $root 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$small = New-Icon 192
$small.Save((Join-Path $root 'icon_192.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$icoBmp = New-Icon 256
$ms = New-Object IO.MemoryStream
$icoBmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$png = $ms.ToArray()
$ms.Dispose()
$ico = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter($ico)
$bw.Write([int16]0); $bw.Write([int16]1); $bw.Write([int16]1)
$bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)
$bw.Write([int16]1); $bw.Write([int16]32)
$bw.Write([int]$png.Length); $bw.Write([int]22)
$bw.Write($png)
$bw.Flush()
[IO.File]::WriteAllBytes((Join-Path $root 'icon.ico'), $ico.ToArray())
$bw.Dispose(); $ico.Dispose()
$icoBmp.Dispose(); $big.Dispose(); $small.Dispose()
Write-Output 'Icon erzeugt: icon.png, icon_192.png, icon.ico'
