param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\assets'))
foreach ($d in @('ui', 'map', 'crests', 'portraits', 'icons')) {
    $p = Join-Path $root $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function C([int]$r, [int]$g, [int]$b, [int]$a = 255) { return [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function B($c) { return New-Object System.Drawing.SolidBrush($c) }
function P($c, [float]$w = 1.0) { return New-Object System.Drawing.Pen($c, $w) }
function Grad($g, [int]$x, [int]$y, [int]$w, [int]$h, $c1, $c2, [float]$angle = 90.0) {
    $rect = New-Object System.Drawing.Rectangle($x, $y, $w, $h)
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, $angle)
    $g.FillRectangle($br, $rect)
    $br.Dispose()
}
function Points([float[]]$xy) {
    $list = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    for ($i = 0; $i -lt $xy.Count; $i += 2) {
        $list.Add([System.Drawing.PointF]::new([single]$xy[$i], [single]$xy[$i + 1]))
    }
    return $list.ToArray()
}
function Finish($bmp, $g, [string]$rel) {
    $g.Dispose()
    $path = Join-Path $root $rel
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# ---------------------------------------------------------------- parchment card
$bmp = New-Object System.Drawing.Bitmap(256, 256)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
Grad $g 0 0 256 256 (C 238 221 184) (C 203 174 124) 90
$r = New-Object System.Random(11)
for ($i = 0; $i -lt 1500; $i++) {
    $x = $r.Next(14, 242); $y = $r.Next(14, 242); $len = $r.Next(2, 11)
    $col = if (($i % 3) -eq 0) { C 255 246 214 30 } else { C 120 92 52 24 }
    $g.DrawLine((P $col 1), $x, $y, [Math]::Min(242, $x + $len), [Math]::Min(242, $y + $r.Next(-2, 3)))
}
for ($i = 0; $i -lt 30; $i++) {
    $g.FillEllipse((B (C 140 105 60 10)), $r.Next(18, 236), $r.Next(18, 236), $r.Next(18, 70), $r.Next(14, 52))
}
$g.DrawRectangle((P (C 58 39 22) 10), 5, 5, 246, 246)
$g.DrawRectangle((P (C 150 110 55) 2), 13, 13, 230, 230)
for ($i = 0; $i -lt 4; $i++) {
    $x = if (($i % 2) -eq 0) { 22 } else { 234 }
    $y = if ($i -lt 2) { 22 } else { 234 }
    $g.FillEllipse((B (C 110 76 34)), $x - 6, $y - 6, 12, 12)
    $g.FillEllipse((B (C 196 156 84)), $x - 3, $y - 3, 6, 6)
}
Finish $bmp $g 'ui/card.png'

# ---------------------------------------------------------------- bronze button
$bmp = New-Object System.Drawing.Bitmap(160, 64)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
Grad $g 0 0 160 64 (C 138 92 44) (C 82 52 24) 90
$g.DrawLine((P (C 202 156 88) 2), 8, 10, 152, 10)
$g.DrawLine((P (C 52 32 14) 2), 6, 56, 154, 56)
$g.DrawRectangle((P (C 48 29 12) 3), 3, 3, 154, 58)
$g.DrawRectangle((P (C 176 128 66) 1), 8, 8, 144, 48)
for ($i = 0; $i -lt 4; $i++) {
    $x = if (($i % 2) -eq 0) { 13 } else { 147 }
    $y = if ($i -lt 2) { 13 } else { 51 }
    $g.FillEllipse((B (C 60 36 14)), $x - 4, $y - 4, 8, 8)
    $g.FillEllipse((B (C 200 158 92)), $x - 2, $y - 2, 4, 4)
}
Finish $bmp $g 'ui/button.png'

# ---------------------------------------------------------------- title panorama
$bmp = New-Object System.Drawing.Bitmap(1600, 720)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
Grad $g 0 0 1600 470 (C 18 26 40) (C 196 112 58) 90
Grad $g 0 470 1600 250 (C 28 62 66) (C 12 30 34) 90
for ($i = 9; $i -ge 1; $i--) {
    $g.FillEllipse((B (C 240 170 90 (10 + $i * 3))), 1110 - $i * 26, 150 - $i * 20, 150 + $i * 52, 130 + $i * 40)
}
$g.FillEllipse((B (C 248 196 120)), 1150, 190, 86, 86)
$g.FillEllipse((B (C 255 228 170)), 1166, 206, 54, 54)
$far = Points @(0, 420, 120, 300, 230, 390, 340, 280, 470, 400, 600, 320, 760, 410, 0, 470)
$g.FillPolygon((B (C 54 58 76)), $far)
$mid = Points @(0, 470, 180, 340, 300, 440, 470, 330, 640, 450, 820, 360, 1000, 460, 1120, 380, 1300, 470, 1600, 430, 1600, 470)
$g.FillPolygon((B (C 40 44 58)), $mid)
$near = Points @(0, 500, 190, 430, 360, 500, 540, 440, 700, 510, 0, 540)
$g.FillPolygon((B (C 28 30 40)), $near)
$g.FillRectangle((B (C 28 30 40)), 900, 430, 380, 60)
for ($s = 0; $s -lt 5; $s++) {
    $w = 380 - $s * 58
    $g.FillRectangle((B (C (34 + $s * 6) (34 + $s * 5) (42 + $s * 4))), 900 + $s * 29, 430 - $s * 30, $w, 30)
}
$g.FillRectangle((B (C 22 22 30)), 1010, 300, 34, 130)
$g.FillRectangle((B (C 22 22 30)), 1130, 300, 34, 130)
$g.FillPolygon((B (C 22 22 30)), (Points @(990, 300, 1077, 262, 1164, 300)))
$rr = New-Object System.Random(5)
for ($i = 0; $i -lt 220; $i++) {
    $y = $rr.Next(475, 700); $x = $rr.Next(0, 1600); $len = $rr.Next(8, 44)
    $g.DrawLine((P (C 120 190 190 26) 1), $x, $y, $x + $len, $y)
}
for ($i = 0; $i -lt 18; $i++) {
    $x = $rr.Next(60, 1540); $y = $rr.Next(120, 300)
    $g.DrawArc((P (C 20 20 26 200) 3), $x, $y, 26, 10, 200, 140)
}
for ($i = 0; $i -lt 3000; $i++) {
    $g.FillRectangle((B (C 0 0 0 12)), $rr.Next(0, 1600), $rr.Next(0, 720), 2, 2)
}
Finish $bmp $g 'ui/title.png'

# ---------------------------------------------------------------- sea texture (tileable)
$bmp = New-Object System.Drawing.Bitmap(256, 256)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
Grad $g 0 0 256 256 (C 20 62 68) (C 8 30 38) 90
$r = New-Object System.Random(23)
for ($i = 0; $i -lt 70; $i++) {
    $x = $r.Next(0, 256); $y = $r.Next(0, 256); $w = $r.Next(12, 40); $h = $r.Next(4, 12)
    foreach ($dx in @(-256, 0, 256)) {
        foreach ($dy in @(-256, 0, 256)) {
            $g.DrawArc((P (C 130 220 220 40) 1.4), $x + $dx, $y + $dy, $w, $h, 200, 140)
        }
    }
}
for ($i = 0; $i -lt 700; $i++) {
    $g.FillRectangle((B (C 160 230 220 16)), $r.Next(0, 256), $r.Next(0, 256), 1, 1)
}
Finish $bmp $g 'map/sea.png'

# ---------------------------------------------------------------- terrain texture
$bmp = New-Object System.Drawing.Bitmap(128, 128)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear((C 206 206 206))
$r = New-Object System.Random(31)
for ($i = 0; $i -lt 800; $i++) {
    $x = $r.Next(0, 128); $y = $r.Next(0, 128)
    $col = if (($i % 2) -eq 0) { C 120 120 120 40 } else { C 255 255 255 46 }
    $g.DrawLine((P $col 1), $x, $y, $x + $r.Next(-4, 5), $y + $r.Next(2, 9))
}
for ($i = 0; $i -lt 12; $i++) {
    $g.DrawArc((P (C 90 90 90 40) 1), $r.Next(0, 110), $r.Next(0, 110), $r.Next(10, 40), $r.Next(6, 22), 0, 180)
}
Finish $bmp $g 'map/terrain.png'

# ---------------------------------------------------------------- crests
$shield = {
    param($g, $brush, $pen)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddLine(18, 12, 142, 12)
    $path.AddLine(142, 12, 142, 104)
    $path.AddBezier(142, 104, 142, 146, 108, 172, 80, 184)
    $path.AddBezier(80, 184, 52, 172, 18, 146, 18, 104)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
    $g.DrawPath($pen, $path)
}
$crestColors = @(
    @(150, 62, 44), @(50, 84, 140), @(52, 112, 66), @(158, 118, 44),
    @(40, 106, 110), @(96, 60, 124), @(150, 126, 44), @(74, 86, 102), @(100, 112, 56)
)
for ($i = 0; $i -lt 9; $i++) {
    $bmp = New-Object System.Drawing.Bitmap(160, 192)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $c = $crestColors[$i]
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddLine(18, 12, 142, 12)
    $path.AddLine(142, 12, 142, 104)
    $path.AddBezier(142, 104, 142, 146, 108, 172, 80, 184)
    $path.AddBezier(80, 184, 52, 172, 18, 146, 18, 104)
    $path.CloseFigure()
    $rect = New-Object System.Drawing.Rectangle(18, 12, 124, 172)
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (C ([Math]::Min(255, $c[0] + 46)) ([Math]::Min(255, $c[1] + 46)) ([Math]::Min(255, $c[2] + 46))), (C ([Math]::Max(0, $c[0] - 46)) ([Math]::Max(0, $c[1] - 46)) ([Math]::Max(0, $c[2] - 46))), 90)
    $g.FillPath($br, $path)
    $br.Dispose()
    $ink = C 250 242 218
    $bronze = C 196 150 78
    $pen = P (C 42 30 18) 6
    $g.DrawPath($pen, $path)
    $g.DrawPath((P $bronze 2), $path)
    switch ($i) {
        0 {
            $g.FillEllipse((B $ink), 56, 64, 48, 48)
            for ($k = 0; $k -lt 8; $k++) {
                $a = $k * [Math]::PI / 4
                $x1 = 80 + [Math]::Cos($a) * 34; $y1 = 88 + [Math]::Sin($a) * 34
                $x2 = 80 + [Math]::Cos($a) * 50; $y2 = 88 + [Math]::Sin($a) * 50
                $g.DrawLine((P $ink 4), [single]$x1, [single]$y1, [single]$x2, [single]$y2)
            }
        }
        1 {
            $g.DrawArc((P $ink 7), 34, 44, 70, 78, 300, 120)
            $g.DrawArc((P $ink 7), 56, 44, 70, 78, 120, 120)
        }
        2 {
            $g.DrawLine((P $ink 6), 80, 46, 80, 138)
            $g.DrawLine((P $ink 6), 52, 78, 80, 46)
            $g.DrawLine((P $ink 6), 108, 78, 80, 46)
            $g.DrawLine((P $ink 6), 50, 60, 110, 60)
        }
        3 {
            $pt = Points @(58, 132, 62, 76, 82, 58, 106, 66, 112, 92, 96, 104, 94, 132)
            $g.FillPolygon((B $ink), $pt)
            $g.FillEllipse((B (C 40 30 20)), 94, 78, 8, 8)
        }
        4 {
            $g.DrawLine((P $ink 8), 62, 54, 62, 140)
            $g.FillPolygon((B $ink), (Points @(62, 66, 112, 52, 118, 96, 62, 100)))
        }
        5 {
            $g.DrawBezier((P $ink 7), 46, 118, 74, 52, 96, 150, 116, 70)
            $g.FillEllipse((B (C 40 30 20)), 108, 58, 12, 12)
        }
        6 {
            $pts = @()
            for ($k = 0; $k -lt 16; $k++) {
                $rad = if (($k % 2) -eq 0) { 48 } else { 20 }
                $a = $k * [Math]::PI / 8 - [Math]::PI / 2
                $pts += [single](80 + [Math]::Cos($a) * $rad)
                $pts += [single](90 + [Math]::Sin($a) * $rad)
            }
            $g.FillPolygon((B $ink), (Points $pts))
        }
        7 {
            for ($k = 0; $k -lt 3; $k++) {
                $y = 72 + $k * 24
                $g.DrawArc((P $ink 5), 38, $y, 84, 30, 200, 140)
            }
        }
        8 {
            $g.FillPolygon((B $ink), (Points @(80, 48, 100, 86, 94, 84, 108, 118, 82, 110, 74, 140, 64, 108, 44, 116, 62, 84, 54, 82)))
        }
    }
    Finish $bmp $g ("crests/crest_{0}.png" -f $i)
}

# ---------------------------------------------------------------- portraits
$bgpal = @(
    @(56, 34, 30), @(34, 42, 60), @(42, 52, 36), @(60, 46, 28),
    @(46, 30, 44), @(32, 46, 52), @(52, 40, 32), @(38, 36, 48),
    @(58, 36, 46), @(40, 50, 42), @(50, 42, 54), @(46, 38, 30)
)
$skins = @(@(228, 182, 144), @(206, 156, 116), @(178, 126, 88), @(146, 98, 66))
$hairs = @(@(38, 25, 16), @(92, 58, 30), @(160, 112, 58), @(74, 74, 78), @(120, 34, 22))
$tunics = @(@(112, 54, 40), @(44, 66, 108), @(48, 86, 52), @(124, 90, 36), @(36, 82, 86), @(80, 50, 100), @(116, 98, 36), @(58, 68, 82), @(78, 88, 44))
for ($i = 0; $i -lt 12; $i++) {
    $bmp = New-Object System.Drawing.Bitmap(256, 320)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $bg = $bgpal[$i]
    $bgC = [System.Drawing.Color]::FromArgb(255, $bg[0], $bg[1], $bg[2])
    $bgD = [System.Drawing.Color]::FromArgb(255, [Math]::Max(0, $bg[0] - 30), [Math]::Max(0, $bg[1] - 30), [Math]::Max(0, $bg[2] - 30))
    Grad $g 0 0 256 320 $bgC $bgD 90
    $g.FillEllipse((B (C 255 214 150 26)), 24, 10, 208, 280)
    $female = $i -ge 8
    $skin = $skins[$i % 4]
    $hair = $hairs[$i % 5]
    $tunic = $tunics[$i % 9]
    $skinC = [System.Drawing.Color]::FromArgb(255, $skin[0], $skin[1], $skin[2])
    $skinShade = [System.Drawing.Color]::FromArgb(255, [Math]::Max(0, $skin[0] - 40), [Math]::Max(0, $skin[1] - 40), [Math]::Max(0, $skin[2] - 40))
    $hairC = [System.Drawing.Color]::FromArgb(255, $hair[0], $hair[1], $hair[2])
    $hairBeard = [System.Drawing.Color]::FromArgb(235, $hair[0], $hair[1], $hair[2])
    $tunicC = [System.Drawing.Color]::FromArgb(255, [Math]::Min(255, $tunic[0] + 18), [Math]::Min(255, $tunic[1] + 18), [Math]::Min(255, $tunic[2] + 18))
    if ($female) { $g.FillEllipse((B $hairC), 50, 42, 156, 236) }
    $g.FillPolygon((B $tunicC), (Points @(20, 320, 40, 248, 96, 218, 160, 218, 216, 248, 236, 320)))
    $g.DrawLine((P (C 200 158 86) 5), 40, 250, 216, 250)
    $g.FillRectangle((B $skinC), 112, 184, 32, 44)
    $g.FillEllipse((B $skinC), 70, 62, 116, 148)
    $g.FillEllipse((B (C 0 0 0 30)), 136, 84, 48, 118)
    $g.FillEllipse((B $skinC), 58, 118, 24, 36)
    $g.FillEllipse((B $skinC), 174, 118, 24, 36)
    if (-not $female) {
        $g.FillEllipse((B $hairC), 62, 38, 132, 96)
        $g.FillRectangle((B $hairC), 58, 92, 18, 44)
        $g.FillRectangle((B $hairC), 180, 92, 18, 44)
    } else {
        $g.FillEllipse((B $hairC), 62, 46, 132, 80)
    }
    $g.FillEllipse((B (C 248 243 232)), 92, 112, 30, 14)
    $g.FillEllipse((B (C 248 243 232)), 134, 112, 30, 14)
    $g.FillEllipse((B (C 42 32 20)), 103, 115, 10, 10)
    $g.FillEllipse((B (C 42 32 20)), 145, 115, 10, 10)
    $g.DrawLine((P $hairC 3), 90, 104, 120, 99)
    $g.DrawLine((P $hairC 3), 136, 99, 166, 104)
    $g.DrawLine((P $skinShade 2), 128, 128, 122, 152)
    $g.DrawLine((P $skinShade 2), 122, 152, 134, 155)
    $g.DrawArc((P (C 96 46 36) 2), 116, 160, 24, 16, 200, 140)
    if ((-not $female) -and (($i % 3) -ne 1)) {
        $g.FillPolygon((B $hairBeard), (Points @(84, 158, 172, 158, 164, 196, 128, 216, 92, 196)))
        $g.DrawLine((P $hairC 5), 110, 170, 146, 170)
    }
    $g.DrawLine((P (C 196 150 78) 6), 74, 96, 182, 96)
    $g.FillEllipse((B (C 120 200 190)), 120, 88, 16, 16)
    for ($k = 0; $k -lt 3; $k++) {
        $g.FillEllipse((B (C 196 150 78)), 110 + $k * 18, 228 + [Math]::Abs($k - 1) * -6, 10, 10)
    }
    $rr = New-Object System.Random(100 + $i)
    for ($k = 0; $k -lt 420; $k++) {
        $g.FillRectangle((B (C 0 0 0 12)), $rr.Next(0, 256), $rr.Next(0, 320), 2, 2)
    }
    Finish $bmp $g ("portraits/portrait_{0}.png" -f $i)
}

# ---------------------------------------------------------------- icons
function Icon($name, [scriptblock]$draw) {
    $bmp = New-Object System.Drawing.Bitmap(64, 64)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    & $draw $g
    Finish $bmp $g ("icons/icon_{0}.png" -f $name)
}
$gold = C 226 178 74
$goldLight = C 252 224 150
$ink = C 44 30 16
$ivory = C 246 238 218

Icon 'gold' {
    param($g)
    $g.FillEllipse((B $gold), 7, 7, 50, 50)
    $g.DrawEllipse((P $ink 4), 7, 7, 50, 50)
    $g.DrawEllipse((P $goldLight 2), 14, 14, 36, 36)
    $g.DrawLine((P $ink 2), 27, 42, 27, 22)
    $g.DrawLine((P $ink 2), 37, 42, 37, 22)
    $g.DrawLine((P $ink 2), 27, 22, 37, 22)
}
Icon 'prestige' {
    param($g)
    $g.DrawArc((P $gold 5), 12, 16, 40, 40, 90, 180)
    $g.DrawArc((P $gold 5), 16, 20, 32, 32, 90, 180)
    $g.FillPolygon((B $goldLight), (Points @(32, 8, 36, 18, 47, 18, 38, 25, 42, 36, 32, 29, 22, 36, 26, 25, 17, 18, 28, 18)))
}
Icon 'sword' {
    param($g)
    $g.FillPolygon((B $ivory), (Points @(32, 4, 38, 14, 36, 40, 28, 40, 26, 14)))
    $g.DrawPolygon((P $ink 2), (Points @(32, 4, 38, 14, 36, 40, 28, 40, 26, 14)))
    $g.DrawLine((P $gold 6), 16, 42, 48, 42)
    $g.DrawLine((P $ink 5), 32, 42, 32, 58)
}
Icon 'heart' {
    param($g)
    $g.FillEllipse((B (C 196 54 58)), 10, 14, 26, 26)
    $g.FillEllipse((B (C 196 54 58)), 28, 14, 26, 26)
    $g.FillPolygon((B (C 196 54 58)), (Points @(8, 30, 56, 30, 32, 58)))
    $g.DrawEllipse((P (C 120 26 30) 2), 10, 14, 26, 26)
}
Icon 'ring' {
    param($g)
    $g.DrawEllipse((P $gold 6), 14, 22, 36, 30)
    $g.FillPolygon((B (C 120 200 220)), (Points @(32, 6, 42, 18, 32, 30, 22, 18)))
    $g.DrawPolygon((P $ink 2), (Points @(32, 6, 42, 18, 32, 30, 22, 18)))
}
Icon 'mask' {
    param($g)
    $g.FillPolygon((B (C 236 224 196)), (Points @(8, 14, 56, 14, 48, 44, 32, 54, 16, 44)))
    $g.DrawPolygon((P $ink 2), (Points @(8, 14, 56, 14, 48, 44, 32, 54, 16, 44)))
    $g.FillEllipse((B $ink), 16, 24, 12, 8)
    $g.FillEllipse((B $ink), 36, 24, 12, 8)
}
Icon 'dagger' {
    param($g)
    $g.FillPolygon((B $ivory), (Points @(32, 4, 38, 16, 35, 38, 29, 38, 26, 16)))
    $g.DrawLine((P $gold 5), 18, 40, 46, 40)
    $g.DrawLine((P $ink 4), 32, 40, 32, 54)
}
Icon 'chain' {
    param($g)
    $g.DrawArc((P (C 186 190 196) 6), 6, 18, 26, 30, 0, 300)
    $g.DrawArc((P (C 186 190 196) 6), 20, 12, 26, 30, 0, 300)
    $g.DrawArc((P (C 120 126 134) 2), 10, 22, 18, 22, 0, 300)
    $g.DrawArc((P (C 120 126 134) 2), 24, 16, 18, 22, 0, 300)
}
Icon 'crown' {
    param($g)
    $g.FillPolygon((B $gold), (Points @(6, 44, 8, 16, 22, 30, 32, 8, 42, 30, 56, 16, 58, 44)))
    $g.DrawPolygon((P $ink 2), (Points @(6, 44, 8, 16, 22, 30, 32, 8, 42, 30, 56, 16, 58, 44)))
    $g.DrawLine((P $ink 2), 6, 44, 58, 44)
    $g.FillEllipse((B (C 150 40 50)), 27, 48, 10, 10)
}
Icon 'scroll' {
    param($g)
    $g.FillRectangle((B (C 238 224 190)), 12, 12, 40, 42)
    $g.DrawRectangle((P $ink 2), 12, 12, 40, 42)
    for ($k = 0; $k -lt 4; $k++) { $g.DrawLine((P (C 120 92 52) 2), 18, 22 + $k * 8, 46, 22 + $k * 8) }
    $g.FillEllipse((B (C 210 190 150)), 8, 8, 10, 50)
    $g.FillEllipse((B (C 210 190 150)), 46, 8, 10, 50)
}

Write-Output ("Assets erzeugt in " + $root)
