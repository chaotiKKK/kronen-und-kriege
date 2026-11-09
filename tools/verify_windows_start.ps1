param(
    [string]$Exe = "F:\banger-queens.exe",
    [int]$WaitSeconds = 30,
    [switch]$GodotVerbose
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outDir = Join-Path $root "build\verify"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$stdout = Join-Path $outDir "windows-start.stdout.log"
$stderr = Join-Path $outDir "windows-start.stderr.log"
$log = Join-Path $outDir "windows-start.godot.log"
$shot = Join-Path $outDir "windows-start.png"
foreach ($file in @($stdout, $stderr, $log, $shot)) {
    Remove-Item -Force -ErrorAction SilentlyContinue $file
}

if (-not (Test-Path $Exe)) { throw "EXE fehlt: $Exe" }
$hash = (Get-FileHash -Algorithm SHA256 $Exe).Hash.ToLowerInvariant()
$size = (Get-Item $Exe).Length
$started = Get-Date

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class Win32Window {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint flags);
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);
}
"@

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$targetScreen = [System.Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.Right } | Select-Object -Last 1
$windowX = $targetScreen.Bounds.Left + 100
$windowY = $targetScreen.Bounds.Top + 60

function Get-WindowTitle([IntPtr]$hWnd) {
    $buffer = New-Object System.Text.StringBuilder 512
    [void][Win32Window]::GetWindowText($hWnd, $buffer, $buffer.Capacity)
    return $buffer.ToString()
}

# Der Logpfad enthaelt Leerzeichen. Start-Process joined die Array-Elemente
# ohne Quoting; deshalb wird hier ein explizit gequoteter Argumentstring benutzt.
$arguments = '--resolution 1280x720 --position {1},{2} --log-file "{0}"' -f $log, $windowX, $windowY
if ($GodotVerbose) { $arguments += ' --verbose' }
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $Exe
$psi.Arguments = $arguments
$psi.WorkingDirectory = $root
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()
$outTask = $p.StandardOutput.ReadToEndAsync()
$errTask = $p.StandardError.ReadToEndAsync()

function Save-Streams {
    try {
        if ($null -ne $outTask) { [System.IO.File]::WriteAllText($stdout, $outTask.Result) }
        if ($null -ne $errTask) { [System.IO.File]::WriteAllText($stderr, $errTask.Result) }
    } catch { }
}

$deadline = (Get-Date).AddSeconds(25)
$handle = [IntPtr]::Zero
$title = ""
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 200
    $p.Refresh()
    if ($p.HasExited) {
        Save-Streams
        $tail = if (Test-Path $log) { Get-Content $log -Tail 20 | Out-String } else { "" }
        throw "EXE endete vor dem Fenster (Exit $($p.ExitCode)).`n$tail"
    }
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) {
        $handle = $p.MainWindowHandle
        $title = Get-WindowTitle $handle
        break
    }
}
if ($handle -eq [IntPtr]::Zero) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    throw "Kein Fenster innerhalb von 25 Sekunden."
}

# Das Startmenue baut sich nach dem Ladebildschirm auf; erst danach ist ein
# aussagekraeftiger Render-Frame vorhanden. MAIN_READY wird am Ende aus dem
# abgeschlossenen Log geprueft (Godot spuelt die Datei erst beim Beenden).
Start-Sleep -Seconds 6
$p.Refresh()
if ($p.HasExited) { Save-Streams; throw "EXE endete nach dem Fenster (Exit $($p.ExitCode))." }
$title = Get-WindowTitle $handle
# Topmost + feste Position: CopyFromScreen darf nicht ein anderes Fenster
# aufnehmen, wenn der Desktop das Spiel nicht in den Vordergrund holt.
[void][Win32Window]::ShowWindow($handle, 5)
[void][Win32Window]::SetWindowPos($handle, [IntPtr](-1), $windowX, $windowY, 0, 0, 0x41)
[void][Win32Window]::SetForegroundWindow($handle)
Start-Sleep -Milliseconds 750

$rect = New-Object Win32Window+RECT
if (-not [Win32Window]::GetWindowRect($handle, [ref]$rect)) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    throw "Fensterrechteck konnte nicht gelesen werden."
}
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -lt 640 -or $height -lt 360) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    throw "Fenster ist zu klein: ${width}x${height}."
}
if (-not [Win32Window]::IsWindowVisible($handle)) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    throw "Fenster ist nicht sichtbar."
}

$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)

function Measure-Frame([System.Drawing.Bitmap]$bmp) {
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    $lo = 255
    $hi = 0
    for ($x = 0; $x -lt $bmp.Width; $x += 17) {
        for ($y = 0; $y -lt $bmp.Height; $y += 17) {
            $c = $bmp.GetPixel($x, $y)
            $luma = [int](($c.R * 299 + $c.G * 587 + $c.B * 114) / 1000)
            if ($luma -lt $lo) { $lo = $luma }
            if ($luma -gt $hi) { $hi = $luma }
            [void]$set.Add("$($c.R),$($c.G),$($c.B)")
        }
    }
    return @{ Colors = $set.Count; MinLuma = $lo; MaxLuma = $hi }
}

$measure = Measure-Frame $bitmap
$printed = $false
if ($measure.Colors -lt 20 -or ($measure.MaxLuma - $measure.MinLuma) -lt 16) {
    # Fallback fuer GPUs, die CopyFromScreen nicht zuverlaessig liefern.
    $graphics2 = [System.Drawing.Graphics]::FromImage($bitmap)
    $hdc = $graphics2.GetHdc()
    $printed = [Win32Window]::PrintWindow($handle, $hdc, 2)
    $graphics2.ReleaseHdc($hdc)
    $graphics2.Dispose()
    $measure = Measure-Frame $bitmap
}
$bitmap.Save($shot, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

if ($measure.Colors -lt 20 -or ($measure.MaxLuma - $measure.MinLuma) -lt 16) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    throw "Render-Frame wirkt leer (Farben=$($measure.Colors), Luma=$($measure.MinLuma)..$($measure.MaxLuma), PrintWindow=$printed)."
}

# Kontrolliertes Ende wie beim Schliessen durch den Nutzer.
[void][Win32Window]::PostMessage($handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
if (-not $p.WaitForExit($WaitSeconds * 1000)) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    throw "Kein kontrolliertes Ende innerhalb von $WaitSeconds Sekunden."
}
$p.Refresh()
$outTask.Wait(2000) | Out-Null
$errTask.Wait(2000) | Out-Null
[System.IO.File]::WriteAllText($stdout, $outTask.Result)
[System.IO.File]::WriteAllText($stderr, $errTask.Result)
$exitCode = $p.ExitCode
if ($null -eq $exitCode) { throw "EXE lieferte keinen Exit-Code." }
if ($exitCode -ne 0) { throw "EXE beendete sich mit Exit $exitCode." }

$bad = @()
foreach ($file in @($log, $stdout, $stderr)) {
    if (-not (Test-Path $file)) { continue }
    $text = Get-Content -Raw $file
    if ($text -match "(?im)^\s*(ERROR|SCRIPT ERROR|FATAL|Unhandled|Exception|Crash)\b") {
        $bad += $file
    }
}
if ($bad.Count -gt 0) { throw "Fehler/Exception in: $($bad -join ', ')" }

$logText = if (Test-Path $log) { Get-Content -Raw $log } else { "" }
if ($logText -notmatch "MAIN_READY") {
    throw "Hauptszene wurde nicht geladen (MAIN_READY fehlt im Log)."
}

$wer = @(Get-WinEvent -FilterHashtable @{LogName = "Application"; StartTime = $started} -ErrorAction SilentlyContinue |
    Where-Object {
        $_.ProviderName -in @("Application Error", "Windows Error Reporting") -and
        $_.Message -match "ck3-kronen-kriege\.exe"
    })
if ($wer.Count -gt 0) { throw "Windows-Crashspur fuer die EXE: $($wer[0].TimeCreated) / $($wer[0].ProviderName)" }

Write-Output "WINDOWSTART OK"
Write-Output "EXE=$Exe"
Write-Output "SIZE=$size"
Write-Output "SHA256=$hash"
Write-Output "WINDOW=${width}x${height}"
Write-Output "TITLE=$title"
Write-Output "VISIBLE=True"
Write-Output "FRAME_COLORS=$($measure.Colors)"
Write-Output "FRAME_LUMA=$($measure.MinLuma)..$($measure.MaxLuma)"
Write-Output "FRAME_PRINTWINDOW=$printed"
Write-Output "EXIT_CODE=$exitCode"
Write-Output "SCREENSHOT=$shot"
Write-Output "STDOUT=$stdout"
Write-Output "STDERR=$stderr"
Write-Output "LOG=$log"
