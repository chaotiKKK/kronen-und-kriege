param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$ExpectedVersion = '1.7.0',
    [ValidateRange(0, 65535)][int]$Port = 0,
    [ValidateRange(10, 180)][int]$PhaseTimeoutSeconds = 120,
    [ValidateRange(30, 600)][int]$OverallTimeoutSeconds = 300,
    [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$exePath = (Resolve-Path -LiteralPath $Exe).Path
if ([IO.Path]::GetExtension($exePath) -ne '.exe') { throw 'Eine tatsächliche exportierte Windows-EXE ist erforderlich.' }
if ($OverallTimeoutSeconds -lt $PhaseTimeoutSeconds) { throw 'Die Gesamtfrist muss mindestens so lang wie eine Phasenfrist sein.' }
$verifyRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\verify'))
$runId = [Guid]::NewGuid().ToString('N')
$outputPath = [IO.Path]::GetFullPath((Join-Path $verifyRoot ('lan-release-170-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $runId.Substring(0, 8))))
if (-not $outputPath.StartsWith($verifyRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Pakettestausgabe muss unter build/verify bleiben.' }
if (Test-Path -LiteralPath $outputPath) { throw 'Die Paketprüfung erfordert einen neuen exklusiven Ausgabeordner.' }
New-Item -ItemType Directory -Path $outputPath | Out-Null
$exeHash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
$templatePath = Join-Path $PSScriptRoot 'lan-release-smoke.gd.in'
$template = Get-Content -LiteralPath $templatePath -Raw -Encoding utf8
if (($template | Select-String -Pattern '__EXPECTATIONS_JSON__' -AllMatches).Matches.Count -ne 1) { throw 'Der externe Helper besitzt keinen eindeutigen Erwartungsplatzhalter.' }
if ($Port -eq 0) {
    $socket = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
    $Port = $socket.Client.LocalEndPoint.Port
    $socket.Dispose()
}
if ($Port -lt 49152) { throw 'Für die isolierte Paketprüfung einen eigenen hohen Port zwischen 49152 und 65535 verwenden.' }
$roles = @{}
foreach ($role in @('host', 'guest')) {
    $roleRoot = [IO.Path]::GetFullPath((Join-Path $outputPath $role))
    if (-not $roleRoot.StartsWith($outputPath + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Rollenpfad verlässt den exklusiven Testordner.' }
    $profile = Join-Path $roleRoot 'profile'
    $work = Join-Path $roleRoot 'empty-work'
    $appdata = Join-Path $profile 'appdata'
    $localdata = Join-Path $profile 'localappdata'
    $temporary = Join-Path $roleRoot 'temp'
    foreach ($path in @($work, $appdata, $localdata, $temporary)) { New-Item -ItemType Directory -Path $path | Out-Null }
    $expectations = [ordered]@{
        run_id = $runId; role = $role; output = $outputPath.Replace('\', '/');
        profile = $profile.Replace('\', '/'); version = $ExpectedVersion; exe_sha256 = $exeHash;
        port = $Port; phase_timeout_ms = $PhaseTimeoutSeconds * 1000; overall_timeout_ms = $OverallTimeoutSeconds * 1000
    }
    $expectedJson = ConvertTo-Json -InputObject $expectations -Compress -Depth 8
    $quotedJson = ConvertTo-Json -InputObject $expectedJson -Compress
    $helper = Join-Path $roleRoot 'packaged-lan-smoke.gd'
    [IO.File]::WriteAllText($helper, $template.Replace('__EXPECTATIONS_JSON__', $quotedJson), [Text.UTF8Encoding]::new($false))
    $expectations | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $roleRoot 'expectations.json') -Encoding utf8
    $roles[$role] = [pscustomobject]@{
        Role = $role; Root = $roleRoot; Profile = $profile; Work = $work; AppData = $appdata; LocalData = $localdata;
        Temp = $temporary; Helper = $helper; Log = (Join-Path $roleRoot 'runtime.godot.log');
        StdoutPath = (Join-Path $roleRoot 'runtime.stdout.log'); StderrPath = (Join-Path $roleRoot 'runtime.stderr.log');
        Process = $null; StdoutTask = $null; StderrTask = $null; StartUtc = $null; LaunchRecord = $null
    }
}
$prepared = [ordered]@{ stage = 'prepared'; run_id = $runId; version = $ExpectedVersion; exe = $exePath;
    exe_sha256 = $exeHash; port = $Port; output = $outputPath; phase_timeout_seconds = $PhaseTimeoutSeconds;
    overall_timeout_seconds = $OverallTimeoutSeconds; physical_android_wlan_test = $false }
$prepared | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputPath 'preparation.json') -Encoding utf8
if ($PrepareOnly) {
    Write-Output ('PACKAGED_LAN_SMOKE_PREPARED ' + ($prepared | ConvertTo-Json -Compress))
    return
}

$overallDeadline = [DateTime]::UtcNow.AddSeconds($OverallTimeoutSeconds)
$succeeded = $false

function Assert-OwnedProcess {
    param($Role)
    $process = $Role.Process
    if ($null -eq $process -or $process.HasExited) { return }
    $actual = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $process.Id)
    if ($null -eq $actual -or -not [string]::Equals([string]$actual.ExecutablePath, $exePath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Prozess $($process.Id) gehört nicht zur eingefrorenen Paket-EXE."
    }
    $command = [string]$actual.CommandLine
    if (-not $command.Contains($Role.Helper) -or -not $command.Contains('--lan-release-run-id=' + $runId) -or -not $command.Contains('--lan-release-role=' + $Role.Role)) {
        throw "Prozess $($process.Id) besitzt nicht dieses exklusive Helperskript und diese Laufkennung."
    }
    if ([Math]::Abs(($actual.CreationDate.ToUniversalTime() - $Role.StartUtc).TotalSeconds) -gt 3) {
        throw "Prozess $($process.Id) besitzt eine andere Startzeit; keine Beendigung."
    }
}

function Stop-OwnedProcess {
    param($Role)
    if ($null -ne $Role.Process -and -not $Role.Process.HasExited) {
        Assert-OwnedProcess $Role
        $Role.Process.Kill()
        if (-not $Role.Process.WaitForExit(5000)) { throw "Eigener Pakettestprozess $($Role.Process.Id) beendet sich nicht." }
    }
}

function Start-Role {
    param($Role)
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $exePath
    $psi.Arguments = '--headless --path "{0}" --script "{1}" --log-file "{2}" -- --lan-release-run-id={3} --lan-release-role={4}' -f $Role.Work, $Role.Helper, $Role.Log, $runId, $Role.Role
    $psi.WorkingDirectory = $Role.Work
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables['APPDATA'] = $Role.AppData
    $psi.EnvironmentVariables['LOCALAPPDATA'] = $Role.LocalData
    $psi.EnvironmentVariables['USERPROFILE'] = $Role.Profile
    $psi.EnvironmentVariables['TEMP'] = $Role.Temp
    $psi.EnvironmentVariables['TMP'] = $Role.Temp
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    if (-not $process.Start()) { throw "Paketprozess $($Role.Role) konnte nicht starten." }
    $Role.Process = $process
    $Role.StartUtc = $process.StartTime.ToUniversalTime()
    $Role.StdoutTask = $process.StandardOutput.ReadToEndAsync()
    $Role.StderrTask = $process.StandardError.ReadToEndAsync()
    Assert-OwnedProcess $Role
    $Role.LaunchRecord = [ordered]@{ role = $Role.Role; pid = $process.Id; exe = $exePath; exe_sha256 = $exeHash;
        started_utc = $Role.StartUtc.ToString('o'); working_directory = $Role.Work; helper = $Role.Helper;
        appdata = $Role.AppData; localappdata = $Role.LocalData; userprofile = $Role.Profile; temp = $Role.Temp;
        arguments = $psi.Arguments; run_id = $runId }
    $Role.LaunchRecord | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Role.Root 'launch.json') -Encoding utf8
}

function Wait-Stage {
    param([scriptblock]$Condition, [string]$Description)
    $phaseDeadline = [DateTime]::UtcNow.AddSeconds($PhaseTimeoutSeconds)
    while ([DateTime]::UtcNow -lt $phaseDeadline -and [DateTime]::UtcNow -lt $overallDeadline) {
        if (& $Condition) { return }
        foreach ($role in $roles.Values) {
            if ($null -ne $role.Process -and $role.Process.HasExited -and $role.Process.ExitCode -ne 0) {
                throw "Paketprozess $($role.Role) brach mit Exit $($role.Process.ExitCode) ab; $Description"
            }
        }
        Start-Sleep -Milliseconds 100
    }
    throw "Frist überschritten: $Description"
}

try {
    Start-Role $roles.host
    $listeningPath = Join-Path $outputPath 'host-listening.json'
    Wait-Stage {
        if (-not (Test-Path -LiteralPath $listeningPath)) { return $false }
        try {
            $marker = Get-Content -LiteralPath $listeningPath -Raw -Encoding utf8 | ConvertFrom-Json
            return $marker.run_id -eq $runId -and $marker.role -eq 'host' -and $marker.stage -eq 'listening' -and $marker.pid -eq $roles.host.Process.Id
        } catch { return $false }
    } 'Tatsächliche exportierte Main-Szene und Hostlistener'
    Start-Role $roles.guest
    Wait-Stage { $roles.host.Process.HasExited -and $roles.guest.Process.HasExited } 'Beide Paket-Spielpfade und geordnetes Verbindungsende'
    foreach ($role in $roles.Values) {
        $role.Process.WaitForExit()
        if ($role.Process.ExitCode -ne 0) { throw "Paketprozess $($role.Role) endete mit Exit $($role.Process.ExitCode)." }
    }
    $hostReport = Get-Content -LiteralPath (Join-Path $outputPath 'host-result.json') -Raw -Encoding utf8 | ConvertFrom-Json
    $guestReport = Get-Content -LiteralPath (Join-Path $outputPath 'guest-result.json') -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($pair in @(@($hostReport, $roles.host), @($guestReport, $roles.guest))) {
        $report = $pair[0]
        $role = $pair[1]
        if ($report.run_id -ne $runId -or $report.pid -ne $role.Process.Id -or $report.role -ne $role.Role -or $report.version -ne $ExpectedVersion -or $report.exe_sha256 -ne $exeHash) {
            throw "Ergebnisidentität stimmt nicht: $($role.Role)"
        }
        if ($report.checks -lt 20 -or $report.failures.Count -ne 0 -or -not $report.observed.references_current) { throw "Unvollständiger oder fehlgeschlagener Main-Paketnachweis: $($role.Role)" }
        $runtimeLog = Get-Content -LiteralPath $role.Log -Raw -Encoding utf8
        $stdout = $role.StdoutTask.Result
        $stderr = $role.StderrTask.Result
        $allLogs = $runtimeLog + "`n" + $stdout + "`n" + $stderr
        if ($allLogs -match '(?im)^\s*(ERROR|SCRIPT ERROR|FATAL|Unhandled|Exception|Crash)\b' -or $allLogs -match 'PACKAGED_LAN_SMOKE FAIL') {
            throw "Engine- oder Prüfungsfehler in den isolierten Paketlogs: $($role.Role)"
        }
        if ($allLogs -notmatch ('MAIN_READY version=' + [regex]::Escape($ExpectedVersion)) -or $allLogs -notmatch ('PACKAGED_LAN_SMOKE OK; role=' + $role.Role)) {
            throw "Produktiver Main-Start oder vollständiger Erfolgsmarker fehlt: $($role.Role)"
        }
    }
    if ($hostReport.observed.world_hash -notmatch '^[0-9a-f]{64}$' -or $hostReport.observed.world_hash -ne $guestReport.observed.world_hash) { throw 'Host und Gast bestätigten keine identische tatsächliche Paketwelt.' }
    if ($hostReport.observed.personal_house -ne 0 -or $guestReport.observed.personal_house -ne 1) { throw 'Die persönlichen Paketperspektiven wurden verwechselt.' }
    if (($hostReport.observed.house_gold | ConvertTo-Json -Compress) -ne ($guestReport.observed.house_gold | ConvertTo-Json -Compress)) { throw 'Kosten unterscheiden sich zwischen den Paketprozessen.' }
    if ([string]::IsNullOrWhiteSpace($guestReport.observed.accepted_message) -or [string]::IsNullOrWhiteSpace($guestReport.observed.rejected_message) -or -not $guestReport.observed.rejected_hint.Contains($guestReport.observed.rejected_message)) {
        throw 'Echte erfolgreiche und abgewiesene Gast-ACKs wurden nicht sichtbar bestätigt.'
    }
    if ((Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $exeHash) { throw 'Die EXE wurde während des Pakettests geändert.' }
    $summary = [ordered]@{ stage = 'packaged-lan-main-smoke'; result = 'PASS'; run_id = $runId; version = $ExpectedVersion;
        exe = $exePath; exe_sha256 = $exeHash; host_pid = $roles.host.Process.Id; guest_pid = $roles.guest.Process.Id;
        checks = $hostReport.checks + $guestReport.checks; world_hash = $hostReport.observed.world_hash;
        isolated_profiles = $true; real_enet_between_processes = $true; real_main_dispatch = $true;
        physical_android_wlan_test = $false; output = $outputPath }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputPath 'summary.json') -Encoding utf8
    $succeeded = $true
    Write-Output ('PACKAGED_LAN_MAIN_OK ' + ($summary | ConvertTo-Json -Compress))
} catch {
    [ordered]@{ stage = 'packaged-lan-main-smoke'; result = 'FAIL'; run_id = $runId; exe = $exePath;
        exe_sha256 = $exeHash; message = $_.Exception.Message; output = $outputPath } |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputPath 'failure.json') -Encoding utf8
    throw
} finally {
    foreach ($role in $roles.Values) {
        if ($null -eq $role.Process) { continue }
        Stop-OwnedProcess $role
        [IO.File]::WriteAllText($role.StdoutPath, $role.StdoutTask.Result)
        [IO.File]::WriteAllText($role.StderrPath, $role.StderrTask.Result)
        if ($null -ne $role.LaunchRecord) {
            $role.LaunchRecord['exit_code'] = $role.Process.ExitCode
            $role.LaunchRecord['completed_utc'] = [DateTime]::UtcNow.ToString('o')
            $role.LaunchRecord | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $role.Root 'launch.json') -Encoding utf8
        }
    }
    if (-not $succeeded) { Write-Output ('Pakettestbelege: ' + $outputPath) }
}
