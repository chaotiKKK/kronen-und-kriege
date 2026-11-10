param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Frozen,
    [int]$TimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$exePath = (Resolve-Path -LiteralPath $Exe).Path
$frozenPath = (Resolve-Path -LiteralPath $Frozen).Path
$expected = Get-Content -LiteralPath $frozenPath -Raw -Encoding UTF8 | ConvertFrom-Json
$outputPath = [IO.Path]::GetFullPath([string]$expected.output)
$verifyRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\verify'))
if (-not $outputPath.StartsWith($verifyRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must stay below build/verify' }
$sandboxPath = [IO.Path]::GetFullPath([string]$expected.sandbox)
if (-not $sandboxPath.StartsWith($outputPath + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Sandbox must stay below the selected output directory' }
if (Test-Path -LiteralPath $sandboxPath) { throw 'Use a fresh frozen output directory; sandbox already exists' }
$workPath = Join-Path $sandboxPath 'empty-work'
$profilePath = Join-Path $sandboxPath 'profile'
$appdataPath = Join-Path $profilePath 'appdata'
$localPath = Join-Path $profilePath 'localappdata'
$tempPath = Join-Path $sandboxPath 'temp'
foreach ($path in @($workPath, $appdataPath, $localPath, $tempPath)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
$smokePath = Join-Path $outputPath 'packaged-smoke.gd'
if (-not (Test-Path -LiteralPath $smokePath)) { throw 'Prepared external smoke script missing' }
Add-Type -AssemblyName System.Windows.Forms
$rightScreen = [Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.Right } | Select-Object -Last 1
$position = '{0},{1}' -f ($rightScreen.Bounds.Left + 100), ($rightScreen.Bounds.Top + 60)
$logPath = Join-Path $outputPath 'runtime.godot.log'
$outPath = Join-Path $outputPath 'runtime.stdout.log'
$errPath = Join-Path $outputPath 'runtime.stderr.log'
$psi = New-Object Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.Arguments = '--path "{0}" --script "{1}" --resolution 1280x720 --position {2} --log-file "{3}"' -f $workPath, $smokePath, $position, $logPath
$psi.WorkingDirectory = $workPath
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$psi.EnvironmentVariables['APPDATA'] = $appdataPath
$psi.EnvironmentVariables['LOCALAPPDATA'] = $localPath
$psi.EnvironmentVariables['USERPROFILE'] = $profilePath
$psi.EnvironmentVariables['TEMP'] = $tempPath
$psi.EnvironmentVariables['TMP'] = $tempPath
$process = New-Object Diagnostics.Process
$process.StartInfo = $psi
$startTime = Get-Date
[void]$process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
try {
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "Isolated runtime smoke timed out after $TimeoutSeconds seconds"
    }
} finally {
    if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    [IO.File]::WriteAllText($outPath, $stdoutTask.Result)
    [IO.File]::WriteAllText($errPath, $stderrTask.Result)
}
if ($process.ExitCode -ne 0) { throw "Isolated runtime smoke exited with code $($process.ExitCode); see $outputPath" }
$logText = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8
$allLogs = $logText + "`n" + $stdoutTask.Result + "`n" + $stderrTask.Result
if ($allLogs -match '(?im)^\s*(ERROR|SCRIPT ERROR|FATAL|Unhandled|Exception|Crash)\b') { throw 'Godot error found in isolated runtime logs' }
$versionPattern = 'MAIN_READY version=' + [regex]::Escape([string]$expected.version)
if ($logText -notmatch $versionPattern -or $logText -notmatch 'PACKAGED_RELEASE_SMOKE OK') { throw 'Real Main scene or complete runtime smoke success marker missing' }
$launchRecord = [ordered]@{ exe = $exePath; exe_sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant(); frozen = $frozenPath; cwd = $workPath; appdata = $appdataPath; position = $position; started = $startTime.ToString('o'); exit_code = $process.ExitCode }
$launchRecord | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputPath 'runtime-launch-receipt.json') -Encoding UTF8
Write-Output ('PACKAGED_RUNTIME_OK ' + ($launchRecord | ConvertTo-Json -Compress))
