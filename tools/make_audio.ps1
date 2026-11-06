param()
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\assets\audio'))
if (-not (Test-Path $root)) { New-Item -ItemType Directory -Force -Path $root | Out-Null }

function Write-Wav([string]$name, [double[]]$samples, [int]$rate = 22050) {
    $n = $samples.Length
    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter($ms)
    $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
    $bw.Write([int](36 + $n * 2))
    $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
    $bw.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
    $bw.Write([int]16)
    $bw.Write([int16]1)
    $bw.Write([int16]1)
    $bw.Write([int]$rate)
    $bw.Write([int]($rate * 2))
    $bw.Write([int16]2)
    $bw.Write([int16]16)
    $bw.Write([Text.Encoding]::ASCII.GetBytes('data'))
    $bw.Write([int]($n * 2))
    foreach ($s in $samples) {
        $v = [int][Math]::Round($s * 32767.0)
        if ($v -gt 32767) { $v = 32767 }
        if ($v -lt -32768) { $v = -32768 }
        $bw.Write([int16]$v)
    }
    $bw.Flush()
    [IO.File]::WriteAllBytes((Join-Path $root $name), $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
    Write-Output ("{0}: {1} Bytes" -f $name, (Get-Item (Join-Path $root $name)).Length)
}

$rate = 22050
$n = $rate * 20
$ambient = New-Object 'double[]' $n
$rnd = New-Object System.Random(7)
$lp = 0.0
$notes = @(196.0, 246.94, 293.66, 220.0, 329.63)
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / [double]$rate
    $swell = 0.55 + 0.45 * [Math]::Sin(2.0 * [Math]::PI * $t / 20.0 - 1.4)
    $v = 0.10 * [Math]::Sin(2.0 * [Math]::PI * 55.0 * $t)
    $v += 0.055 * [Math]::Sin(2.0 * [Math]::PI * 82.5 * $t + 0.5)
    $v += 0.030 * [Math]::Sin(2.0 * [Math]::PI * 110.0 * $t + 1.2)
    $lp = $lp * 0.975 + ($rnd.NextDouble() * 2.0 - 1.0) * 0.025
    $v += $lp * 0.55
    $pt = $t % 5.0
    if ($pt -lt 2.8) {
        $k = [int]([Math]::Floor($t / 5.0)) % $notes.Length
        $f = $notes[$k]
        $v += 0.055 * [Math]::Exp(-$pt * 1.7) * [Math]::Sin(2.0 * [Math]::PI * $f * $pt)
        $v += 0.025 * [Math]::Exp(-$pt * 2.3) * [Math]::Sin(2.0 * [Math]::PI * $f * 2.01 * $pt)
    }
    $env = 1.0
    if ($t -lt 0.35) { $env = $t / 0.35 }
    if ($t -gt 19.65) { $env = (20.0 - $t) / 0.35 }
    $ambient[$i] = $v * $swell * $env
}
Write-Wav 'ambient.wav' $ambient $rate

$n = [int]($rate * 0.14)
$click = New-Object 'double[]' $n
$rnd = New-Object System.Random(11)
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / [double]$rate
    $env = [Math]::Exp(-$t * 38.0)
    $click[$i] = (0.35 * [Math]::Sin(2.0 * [Math]::PI * 760.0 * $t) + 0.18 * ($rnd.NextDouble() * 2.0 - 1.0)) * $env
}
Write-Wav 'click.wav' $click $rate

$n = [int]($rate * 0.45)
$open = New-Object 'double[]' $n
$rnd = New-Object System.Random(13)
$lp = 0.0
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / [double]$rate
    $env = [Math]::Sin([Math]::PI * [Math]::Min(1.0, $t / 0.44))
    $f = 190.0 - 95.0 * ($t / 0.45)
    $lp = $lp * 0.94 + ($rnd.NextDouble() * 2.0 - 1.0) * 0.06
    $open[$i] = (0.22 * [Math]::Sin(2.0 * [Math]::PI * $f * $t) + $lp * 0.35) * $env
}
Write-Wav 'open.wav' $open $rate
Write-Output 'Audio erzeugt.'
