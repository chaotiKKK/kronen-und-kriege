param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Output,
    [ValidateRange(30, 300)][int]$TimeoutSeconds = 180,
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
$helperSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'choice-guards-release-smoke.gd.in')).Path
$helperHash = (Get-FileHash -LiteralPath $helperSource -Algorithm SHA256).Hash.ToLowerInvariant()
$exeHash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
$sidecarPath = [IO.Path]::ChangeExtension($exePath, '.pck')
$sidecarHash = $null
if (Test-Path -LiteralPath $sidecarPath) { $sidecarHash = (Get-FileHash -LiteralPath $sidecarPath -Algorithm SHA256).Hash.ToLowerInvariant() }
Add-Type -AssemblyName System.Windows.Forms
$screens = @([Windows.Forms.Screen]::AllScreens)
if ($screens.Count -eq 0) { throw 'No physical monitor is available for the rendered release probe.' }
$rightScreen = $screens | Sort-Object { $_.Bounds.Right } | Select-Object -Last 1
$position = '{0},{1}' -f ($rightScreen.WorkingArea.Left + 40), ($rightScreen.WorkingArea.Top + 40)
$width = [Math]::Min(1600, $rightScreen.WorkingArea.Width - 80)
$height = [Math]::Min(900, $rightScreen.WorkingArea.Height - 100)
if ($width -lt 800 -or $height -lt 600) { throw 'Rightmost monitor is too small for the rendered release probe.' }
$resolution = '{0}x{1}' -f $width, $height
New-Item -ItemType Directory -Path $outputPath | Out-Null
$helperPath = Join-Path $outputPath 'choice-guards-release-smoke.gd'
Copy-Item -LiteralPath $helperSource -Destination $helperPath
if ((Get-FileHash -LiteralPath $helperPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $helperHash) { throw 'Frozen helper copy does not match its template.' }
$sandbox = Join-Path $outputPath 'sandbox'
$work = Join-Path $sandbox 'empty-work'
$probeProfile = Join-Path $sandbox 'profile'
$appdata = Join-Path $probeProfile 'appdata'
$localdata = Join-Path $probeProfile 'localappdata'
$temporary = Join-Path $sandbox 'temp'
foreach ($path in @($work, $appdata, $localdata, $temporary)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
$godotLog = Join-Path $outputPath 'runtime.godot.log'
$stdoutPath = Join-Path $outputPath 'runtime.stdout.log'
$stderrPath = Join-Path $outputPath 'runtime.stderr.log'
$resultPath = Join-Path $outputPath 'choice-guards-result.json'
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
$psi.EnvironmentVariables['USERPROFILE'] = $probeProfile
$psi.EnvironmentVariables['TEMP'] = $temporary
$psi.EnvironmentVariables['TMP'] = $temporary
$psi.EnvironmentVariables['BQ_CHOICE_EXPECTED_VERSION'] = $ExpectedVersion
$psi.EnvironmentVariables['BQ_CHOICE_TIMEOUT_SECONDS'] = [string]$TimeoutSeconds
$record = [ordered]@{
    format = 'banger-queens-choice-guards-release-launch/v1'; passed = $false; failure = $null;
    exe = $exePath; exe_sha256_before = $exeHash; exe_sha256_after = $null;
    sidecar_pck = $(if ($null -ne $sidecarHash) { $sidecarPath } else { $null }); sidecar_sha256_before = $sidecarHash; sidecar_sha256_after = $null;
    helper_source = $helperSource; helper = $helperPath; helper_sha256_before = $helperHash; helper_sha256_after = $null; helper_source_sha256_after = $null;
    arguments = $psi.Arguments; working_directory = $work; appdata = $appdata; localappdata = $localdata;
    userprofile = $probeProfile; temp = $temporary; output = $outputPath; expected_version = $ExpectedVersion;
    position = $position; resolution = $resolution; monitor_device = $rightScreen.DeviceName;
    monitor_bounds = $rightScreen.Bounds.ToString(); monitor_working_area = $rightScreen.WorkingArea.ToString(); timeout_seconds = $TimeoutSeconds;
    started_utc = $null; ended_utc = $null; pid = $null; exit_code = $null; timed_out = $false; process_exited = $false; killed_own_process = $false;
    result = $null; checks = $null; failures = $null; screenshots = @(); logs = @();
    resource_scope = 'res:// from exported EXE/PCK; external frozen helper; empty working directory';
    fixture_scope = 'Controlled UI-only treasury 3->6->0 and original Tempeldach event; separate disposable owner-change fixture for minimap invalidation; not a normal campaign progression claim';
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
    $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $launchPath -Encoding UTF8
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $record.timed_out = $true
        throw "Choice guard release probe exceeded $TimeoutSeconds seconds."
    }
} catch {
    $caught = $_.Exception.Message
} finally {
    # Control only the exact Process returned by our Start. No process-name,
    # PID enumeration, ADB or other game's emulator is touched.
    if ($started -and -not $process.HasExited) {
        try {
            $process.Kill()
            $record.killed_own_process = $true
            if (-not $process.WaitForExit(5000)) { $caught = 'Our release probe did not terminate after Kill.' }
        } catch {
            if (-not $process.HasExited) { $caught = 'Our exact release process could not be terminated: ' + $_.Exception.Message }
        }
    }
    if ($started -and $process.HasExited) {
        $record.exit_code = $process.ExitCode
        $record.process_exited = $true
    }
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
    # Record final hashes even when the probe timed out or had failed checks.
    if (Test-Path -LiteralPath $exePath) { $record.exe_sha256_after = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    if (Test-Path -LiteralPath $helperPath) { $record.helper_sha256_after = (Get-FileHash -LiteralPath $helperPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    if (Test-Path -LiteralPath $helperSource) { $record.helper_source_sha256_after = (Get-FileHash -LiteralPath $helperSource -Algorithm SHA256).Hash.ToLowerInvariant() }
    if (Test-Path -LiteralPath $sidecarPath) { $record.sidecar_sha256_after = (Get-FileHash -LiteralPath $sidecarPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    if ($null -ne $caught) { throw $caught }
    if ($record.exit_code -ne 0 -or -not $record.process_exited) { throw "Exported EXE did not exit cleanly (code $($record.exit_code))." }
    if ($record.exe_sha256_after -ne $exeHash -or $record.helper_sha256_after -ne $helperHash -or $record.helper_source_sha256_after -ne $helperHash -or $record.sidecar_sha256_after -ne $sidecarHash) { throw 'EXE/PCK, frozen helper or template changed during the run.' }
    if (-not (Test-Path -LiteralPath $godotLog)) { throw 'Godot runtime log is missing.' }
    $logs = (Get-Content -LiteralPath $godotLog -Raw -Encoding UTF8) + "`n" + $stdout + "`n" + $stderr
    if ($logs -match '(?im)\b(SCRIPT ERROR|ERROR|FATAL|FAIL|Unhandled|Exception|Crash)\b') { throw 'An error or failure marker appears in the runtime logs.' }
    if ($logs -notmatch ('MAIN_READY version=' + [regex]::Escape($ExpectedVersion)) -or $logs -notmatch 'CHOICE_GUARDS_RELEASE OK: \d+ checks, 0 failures') { throw 'Complete Main/choice-guards success markers are missing.' }
    if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Structured helper result is missing.' }
    $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $record.result = [ordered]@{ path = $resultPath; sha256 = (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    $record.checks = [int]$result.checks
    $record.failures = [int]$result.failures
    if ($result.passed -ne $true -or $result.failures -ne 0 -or $result.checks -lt 60 -or $result.version -ne $ExpectedVersion) { throw 'Helper result has failed checks, wrong version or an incomplete check count.' }
    if ([int]$result.process_id -ne $record.pid -or [IO.Path]::GetFullPath([string]$result.executable) -ne $exePath) { throw 'Helper receipt does not belong to our exact launched executable/process.' }
    $reportedProfile = [IO.Path]::GetFullPath([string]$result.user_data_dir)
    if (-not $reportedProfile.StartsWith($appdata + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Godot user data escaped the isolated APPDATA profile.' }
    if (@($result.results).Count -ne $result.checks -or @($result.results | Where-Object { $_.ok -ne $true }).Count -ne 0) { throw 'Structured per-check results do not match the successful aggregate.' }
    if ($result.render_validation -ne 'rendered_root_viewport' -or $result.resource_scope -ne 'res resources embedded in the launched release executable') { throw 'A headless/source-only probe cannot certify this rendered package.' }
    if (@($result.evidence.minimap.pans).Count -ne 6 -or @($result.evidence.controlled_event_fixture.stages).Count -ne 3) { throw 'Camera pan or 3->6->0 event transition evidence is incomplete.' }
    $expectedShots = @('01-normal-main-before-fixtures', '02-event-gold3-disabled-costs-and-decline', '03-event-gold6-refresh-and-focus', '04-event-gold0-refresh-and-focus', '05-event-declined-without-reward', '06-event-exact-price-before-real-button', '07-event-paid-with-full-cost', '08-minimap-before-camera-pans', '09-minimap-after-six-real-camera-pans', '10-minimap-owner-invalidation', '11-minimap-terrain-mode-invalidation')
    if (@($result.screenshots).Count -ne $expectedShots.Count) { throw 'All eleven named rendered screenshots are required.' }
    $seenShots = @()
    foreach ($image in $result.screenshots) {
        $imagePath = [IO.Path]::GetFullPath([string]$image)
        if (-not $imagePath.StartsWith($outputPath + '\', [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $imagePath) -or (Get-Item -LiteralPath $imagePath).Length -le 0) { throw 'A screenshot is missing or escapes this run directory.' }
        $name = [IO.Path]::GetFileNameWithoutExtension($imagePath)
        if ($expectedShots -notcontains $name -or $seenShots -contains $name) { throw 'Screenshot names are duplicated or unexpected.' }
        $seenShots += $name
        $record.screenshots += [ordered]@{ path = $imagePath; bytes = (Get-Item -LiteralPath $imagePath).Length; sha256 = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $record.passed = $true
} catch {
    $record.failure = $_.Exception.Message
} finally {
    foreach ($log in @($godotLog, $stdoutPath, $stderrPath)) {
        if (Test-Path -LiteralPath $log) { $record.logs += [ordered]@{ path = $log; bytes = (Get-Item -LiteralPath $log).Length; sha256 = (Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant() } }
    }
    $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $launchPath -Encoding UTF8
    $process.Dispose()
}
if (-not $record.passed) { throw "CHOICE_GUARDS_RELEASE_FAILED: $($record.failure) Evidence: $outputPath" }
Write-Output ('CHOICE_GUARDS_RELEASE_VERIFIED ' + ([ordered]@{ output = $outputPath; exe_sha256 = $exeHash; helper_sha256 = $helperHash; pid = $record.pid; process_exited = $record.process_exited; exit_code = $record.exit_code; checks = $record.checks; failures = $record.failures } | ConvertTo-Json -Compress))
