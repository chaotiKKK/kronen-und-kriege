param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Output,
    [ValidateRange(10, 300)][int]$TimeoutSeconds = 300,
    [string]$ExpectedVersion = '1.9.1'
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$verifyRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\verify'))
$exePath = (Resolve-Path -LiteralPath $Exe).Path
if ([IO.Path]::GetExtension($exePath) -ne '.exe') { throw 'An exported Windows EXE is required.' }
$outputPath = [IO.Path]::GetFullPath($Output)
if (-not $outputPath.StartsWith($verifyRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must remain below this project''s build/verify directory.' }
if (Test-Path -LiteralPath $outputPath) { throw 'Use a fresh output directory; existing evidence must remain unchanged.' }
$helperSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'gameplay-release-smoke.gd.in')).Path
$helperHash = (Get-FileHash -LiteralPath $helperSource -Algorithm SHA256).Hash.ToLowerInvariant()
$exeHash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
New-Item -ItemType Directory -Path $outputPath | Out-Null
$helperPath = Join-Path $outputPath 'gameplay-release-smoke.gd'
Copy-Item -LiteralPath $helperSource -Destination $helperPath
$sandbox = Join-Path $outputPath 'sandbox'
$work = Join-Path $sandbox 'empty-work'
$profile = Join-Path $sandbox 'profile'
$appdata = Join-Path $profile 'appdata'
$localdata = Join-Path $profile 'localappdata'
$temporary = Join-Path $sandbox 'temp'
foreach ($path in @($work, $appdata, $localdata, $temporary)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
Add-Type -AssemblyName System.Windows.Forms
$screens = @([Windows.Forms.Screen]::AllScreens)
$rightScreen = $screens | Sort-Object { $_.Bounds.Right } | Select-Object -Last 1
$position = '{0},{1}' -f ($rightScreen.Bounds.Left + 40), ($rightScreen.Bounds.Top + 40)
$width = [Math]::Min(1600, $rightScreen.WorkingArea.Width - 80)
$height = [Math]::Min(900, $rightScreen.WorkingArea.Height - 100)
if ($width -lt 800 -or $height -lt 600) { throw 'Rightmost monitor is too small for the rendered release probe.' }
$resolution = '{0}x{1}' -f $width, $height
$godotLog = Join-Path $outputPath 'runtime.godot.log'
$stdoutPath = Join-Path $outputPath 'runtime.stdout.log'
$stderrPath = Join-Path $outputPath 'runtime.stderr.log'
$resultPath = Join-Path $outputPath 'gameplay-result.json'
$launchPath = Join-Path $outputPath 'runtime-launch-receipt.json'
$psi = [Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $exePath
$psi.Arguments = '--path "{0}" --script "{1}" --resolution {2} --position {3} --log-file "{4}" -- "{5}"' -f $work, $helperPath, $resolution, $position, $godotLog, $outputPath
$psi.WorkingDirectory = $work
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.EnvironmentVariables['APPDATA'] = $appdata
$psi.EnvironmentVariables['LOCALAPPDATA'] = $localdata
$psi.EnvironmentVariables['USERPROFILE'] = $profile
$psi.EnvironmentVariables['TEMP'] = $temporary
$psi.EnvironmentVariables['TMP'] = $temporary
$record = [ordered]@{
    format = 'banger-queens-gameplay-release-launch/v1'; passed = $false; failure = $null;
    exe = $exePath; exe_sha256 = $exeHash; helper_source = $helperSource; helper = $helperPath; helper_sha256 = $helperHash;
    arguments = $psi.Arguments; working_directory = $work; appdata = $appdata; localappdata = $localdata;
    userprofile = $profile; temp = $temporary; output = $outputPath; expected_version = $ExpectedVersion;
    position = $position; resolution = $resolution; monitor_device = $rightScreen.DeviceName;
    monitor_bounds = $rightScreen.Bounds.ToString(); timeout_seconds = $TimeoutSeconds;
    started_utc = $null; ended_utc = $null; pid = $null; exit_code = $null; timed_out = $false;
    result = $null; checks = $null; failures = $null; screenshots = @(); logs = @();
    physical_android_or_wlan_verified = $false
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$started = $false
$stdoutTask = $null
$stderrTask = $null
$stdout = ''
$stderr = ''
$caught = $null
try {
    if (-not $process.Start()) { throw 'Exported EXE could not be started.' }
    $started = $true
    $record.pid = $process.Id
    $record.started_utc = $process.StartTime.ToUniversalTime().ToString('o')
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $launchPath -Encoding UTF8
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $record.timed_out = $true
        throw "Strategy UI release probe exceeded $TimeoutSeconds seconds."
    }
} catch {
    $caught = $_.Exception.Message
} finally {
    # This is the exact Process object returned by our own Start, never an enumerated PID or global name.
    if ($started -and -not $process.HasExited) {
        $process.Kill()
        if (-not $process.WaitForExit(5000)) { $caught = 'Our release probe did not terminate after Kill.' }
    }
    if ($started -and $process.HasExited) { $record.exit_code = $process.ExitCode }
    if ($null -ne $stdoutTask) {
        if ($stdoutTask.Wait(5000)) { $stdout = $stdoutTask.Result } else { $caught = 'Stdout capture did not complete.' }
    }
    if ($null -ne $stderrTask) {
        if ($stderrTask.Wait(5000)) { $stderr = $stderrTask.Result } else { $caught = 'Stderr capture did not complete.' }
    }
    [IO.File]::WriteAllText($stdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, $stderr, [Text.UTF8Encoding]::new($false))
    $record.ended_utc = [DateTime]::UtcNow.ToString('o')
}
try {
    if ($null -ne $caught) { throw $caught }
    if ($record.exit_code -ne 0) { throw "Exported EXE exited with code $($record.exit_code)." }
    if (-not (Test-Path -LiteralPath $godotLog)) { throw 'Godot runtime log is missing.' }
    $logs = (Get-Content -LiteralPath $godotLog -Raw -Encoding UTF8) + "`n" + $stdout + "`n" + $stderr
    if ($logs -match '(?im)\b(SCRIPT ERROR|ERROR|FATAL|FAIL|Unhandled|Exception|Crash)\b') { throw 'An error or failure marker appears in the runtime logs.' }
    if ($logs -notmatch ('MAIN_READY version=' + [regex]::Escape($ExpectedVersion)) -or $logs -notmatch 'GAMEPLAY_RELEASE OK: \d+ checks, 0 failures') { throw 'Complete Main/strategy success markers are missing.' }
    if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Structured helper result is missing.' }
    $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($result.passed -ne $true -or $result.failures -ne 0 -or $result.checks -lt 40 -or $result.version -ne $ExpectedVersion) { throw 'Helper result has failed checks, wrong version or an incomplete check count.' }
    if (@($result.results).Count -ne $result.checks -or @($result.results | Where-Object { $_.ok -ne $true }).Count -ne 0) { throw 'Structured per-check results do not match the successful aggregate.' }
    if (@($result.screenshots).Count -lt 4) { throw 'Expected at least four rendered screenshots.' }
    foreach ($image in $result.screenshots) {
        $imagePath = [IO.Path]::GetFullPath([string]$image)
        if (-not $imagePath.StartsWith($outputPath + '\', [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $imagePath) -or (Get-Item -LiteralPath $imagePath).Length -le 0) { throw 'A screenshot is missing or escapes this run directory.' }
        $record.screenshots += [ordered]@{ path = $imagePath; bytes = (Get-Item -LiteralPath $imagePath).Length; sha256 = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    if ((Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $exeHash -or (Get-FileHash -LiteralPath $helperPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $helperHash) { throw 'EXE or frozen helper changed during the run.' }
    $record.result = [ordered]@{ path = $resultPath; sha256 = (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    $record.checks = [int]$result.checks
    $record.failures = [int]$result.failures
    $record.passed = $true
} catch {
    $record.failure = $_.Exception.Message
} finally {
    foreach ($log in @($godotLog, $stdoutPath, $stderrPath)) {
        if (Test-Path -LiteralPath $log) { $record.logs += [ordered]@{ path = $log; bytes = (Get-Item -LiteralPath $log).Length; sha256 = (Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant() } }
    }
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $launchPath -Encoding UTF8
    $process.Dispose()
}
if (-not $record.passed) { throw "GAMEPLAY_RELEASE_FAILED: $($record.failure) Evidence: $outputPath" }
Write-Output ('GAMEPLAY_RELEASE_VERIFIED ' + ([ordered]@{ output = $outputPath; exe_sha256 = $exeHash; helper_sha256 = $helperHash; exit_code = $record.exit_code; checks = $record.checks; failures = $record.failures } | ConvertTo-Json -Compress))
