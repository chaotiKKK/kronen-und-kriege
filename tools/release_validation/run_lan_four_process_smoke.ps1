param(
    [string]$ExpectedVersion = '1.7.0',
    [ValidateRange(0, 65535)][int]$Port = 0,
    [ValidateRange(10, 180)][int]$PhaseTimeoutSeconds = 120,
    [ValidateRange(30, 600)][int]$OverallTimeoutSeconds = 300,
    [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$godotPath = (Resolve-Path -LiteralPath (Join-Path $projectRoot '.tools\godot.exe')).Path
if ($OverallTimeoutSeconds -lt $PhaseTimeoutSeconds) { throw 'Die Gesamtfrist muss mindestens eine Phasenfrist umfassen.' }
$verifyRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\verify'))
$runId = [Guid]::NewGuid().ToString('N')
$outputPath = [IO.Path]::GetFullPath((Join-Path $verifyRoot ('lan-four-process-170-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $runId.Substring(0, 8))))
if (-not $outputPath.StartsWith($verifyRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Vier-Prozesse-Ausgabe muss unter build/verify bleiben.' }
if (Test-Path -LiteralPath $outputPath) { throw 'Für den Vier-Prozesse-Nachweis einen neuen exklusiven Ordner verwenden.' }
New-Item -ItemType Directory -Path $outputPath | Out-Null
$engineHash = (Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.ToLowerInvariant()
$sourceHashes = [ordered]@{}
foreach ($name in @('Data', 'Game', 'SaveGame', 'SystemicResolver', 'UiKernel', 'LanProtocol', 'LanAuthority', 'LanDiscovery', 'LanSession')) {
    $resourcePath = 'res://scripts/' + $name + '.gd'
    $sourceHashes[$resourcePath] = (Get-FileHash -LiteralPath (Join-Path $projectRoot ('scripts\' + $name + '.gd')) -Algorithm SHA256).Hash.ToLowerInvariant()
}
$template = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'lan-four-process.gd.in') -Raw -Encoding utf8
if (($template | Select-String -Pattern '__EXPECTATIONS_JSON__' -AllMatches).Matches.Count -ne 1) { throw 'Eindeutiger Erwartungsplatzhalter fehlt im Vier-Prozesse-Helper.' }
if ($Port -eq 0) {
    $socket = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
    $Port = $socket.Client.LocalEndPoint.Port
    $socket.Dispose()
}
if ($Port -lt 49152) { throw 'Der Test benötigt einen eigenen hohen Port zwischen 49152 und 65535.' }
$roleNames = @('host', 'guest1', 'guest2', 'guest3')
$roles = @{}
for ($index = 0; $index -lt $roleNames.Count; $index++) {
    $role = $roleNames[$index]
    $roleRoot = [IO.Path]::GetFullPath((Join-Path $outputPath $role))
    if (-not $roleRoot.StartsWith($outputPath + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Rollenpfad verlässt die eigene Ausgabe.' }
    $roleProfilePath = Join-Path $roleRoot 'profile'
    $appdata = Join-Path $roleProfilePath 'appdata'
    $localdata = Join-Path $roleProfilePath 'localappdata'
    $temporary = Join-Path $roleRoot 'temp'
    $work = Join-Path $roleRoot 'empty-work'
    foreach ($path in @($appdata, $localdata, $temporary, $work)) { New-Item -ItemType Directory -Path $path | Out-Null }
    $expectations = [ordered]@{ run_id = $runId; role = $role; house = $index; port = $Port;
        output = $outputPath.Replace('\', '/'); project = $projectRoot.Replace('\', '/'); profile = $roleProfilePath.Replace('\', '/');
        version = $ExpectedVersion; engine_sha256 = $engineHash; source_sha256 = $sourceHashes;
        test_fingerprint = 'EXPLICIT-FOUR-PROCESS-SOURCE-TEST-' + $runId;
        phase_timeout_ms = $PhaseTimeoutSeconds * 1000; overall_timeout_ms = $OverallTimeoutSeconds * 1000 }
    $json = ConvertTo-Json -InputObject $expectations -Depth 10 -Compress
    $literal = ConvertTo-Json -InputObject $json -Compress
    $helper = Join-Path $roleRoot 'lan-four-process.gd'
    [IO.File]::WriteAllText($helper, $template.Replace('__EXPECTATIONS_JSON__', $literal), [Text.UTF8Encoding]::new($false))
    $expectations | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $roleRoot 'expectations.json') -Encoding utf8
    $roles[$role] = [pscustomobject]@{ Role = $role; House = $index; Root = $roleRoot; Profile = $roleProfilePath;
        AppData = $appdata; LocalData = $localdata; Temp = $temporary; Work = $work; Helper = $helper;
        Log = (Join-Path $roleRoot 'runtime.godot.log'); StdoutPath = (Join-Path $roleRoot 'runtime.stdout.log');
        StderrPath = (Join-Path $roleRoot 'runtime.stderr.log'); Process = $null; StdoutTask = $null;
        StderrTask = $null; StartUtc = $null; LaunchRecord = $null }
}
$preparation = [ordered]@{ stage = 'prepared-source-lan-four-process'; run_id = $runId; version = $ExpectedVersion;
    engine = $godotPath; engine_sha256 = $engineHash; source_sha256 = $sourceHashes; port = $Port; output = $outputPath;
    phase_timeout_seconds = $PhaseTimeoutSeconds; overall_timeout_seconds = $OverallTimeoutSeconds;
    explicit_test_fingerprint_override = $true; package_verified = $false; physical_android_wlan_test = $false }
$preparation | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'preparation.json') -Encoding utf8
if ($PrepareOnly) {
    Write-Output ('LAN_FOUR_PROCESS_SMOKE_PREPARED ' + ($preparation | ConvertTo-Json -Compress -Depth 10))
    return
}

$overallDeadline = [DateTime]::UtcNow.AddSeconds($OverallTimeoutSeconds)
$succeeded = $false

function Assert-OwnedProcess {
    param($Role)
    if ($null -eq $Role.Process -or $Role.Process.HasExited) { return }
    $actual = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $Role.Process.Id)
    if ($null -eq $actual -or -not [string]::Equals([string]$actual.ExecutablePath, $godotPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Prozess $($Role.Process.Id) gehört nicht zur vorgesehenen Godot-EXE."
    }
    $command = [string]$actual.CommandLine
    if (-not $command.Contains($Role.Helper) -or -not $command.Contains('--lan-four-run-id=' + $runId) -or -not $command.Contains('--lan-four-role=' + $Role.Role)) {
        throw "Prozess $($Role.Process.Id) besitzt nicht dieses eigene Helperskript, diese Rolle und diese Laufkennung."
    }
    if ([Math]::Abs(($actual.CreationDate.ToUniversalTime() - $Role.StartUtc).TotalSeconds) -gt 3) { throw 'Prozessstartzeit stimmt nicht; keine Prozessbeendigung.' }
}

function Stop-OwnedProcess {
    param($Role)
    if ($null -ne $Role.Process -and -not $Role.Process.HasExited) {
        Assert-OwnedProcess $Role
        $Role.Process.Kill()
        if (-not $Role.Process.WaitForExit(5000)) { throw "Eigener Testprozess $($Role.Process.Id) beendet sich nicht." }
    }
}

function Start-Role {
    param($Role)
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $godotPath
    $psi.Arguments = '--headless --path "{0}" --script "{1}" --log-file "{2}" -- --lan-four-run-id={3} --lan-four-role={4}' -f $projectRoot, $Role.Helper, $Role.Log, $runId, $Role.Role
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
    if (-not $process.Start()) { throw "Vier-Prozesse-Rolle $($Role.Role) konnte nicht starten." }
    $Role.Process = $process
    $Role.StartUtc = $process.StartTime.ToUniversalTime()
    $Role.StdoutTask = $process.StandardOutput.ReadToEndAsync()
    $Role.StderrTask = $process.StandardError.ReadToEndAsync()
    Assert-OwnedProcess $Role
    $Role.LaunchRecord = [ordered]@{ role = $Role.Role; house = $Role.House; pid = $process.Id; run_id = $runId;
        engine = $godotPath; engine_sha256 = $engineHash; started_utc = $Role.StartUtc.ToString('o');
        helper = $Role.Helper; arguments = $psi.Arguments; working_directory = $Role.Work;
        appdata = $Role.AppData; localappdata = $Role.LocalData; userprofile = $Role.Profile; temp = $Role.Temp }
    $Role.LaunchRecord | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Role.Root 'launch.json') -Encoding utf8
}

function Wait-Stage {
    param([scriptblock]$Condition, [string]$Description)
    $phaseDeadline = [DateTime]::UtcNow.AddSeconds($PhaseTimeoutSeconds)
    while ([DateTime]::UtcNow -lt $phaseDeadline -and [DateTime]::UtcNow -lt $overallDeadline) {
        if (& $Condition) { return }
        foreach ($role in $roles.Values) {
            if ($null -ne $role.Process -and $role.Process.HasExited -and $role.Process.ExitCode -ne 0) {
                throw "Rolle $($role.Role) brach mit Exit $($role.Process.ExitCode) ab; $Description"
            }
        }
        Start-Sleep -Milliseconds 100
    }
    throw "Frist überschritten: $Description"
}

function Test-Marker {
    param([string]$RoleName, [string]$Stage)
    $path = Join-Path $outputPath ($RoleName + '-' + $Stage + '.json')
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    try {
        $marker = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
        return $marker.run_id -eq $runId -and $marker.role -eq $RoleName -and $marker.stage -eq $Stage -and $marker.pid -eq $roles[$RoleName].Process.Id
    } catch { return $false }
}

try {
    Start-Role $roles.host
    Wait-Stage { Test-Marker 'host' 'listening' } 'Echter Quellhost hat seinen ENet-Listener geöffnet'
    foreach ($roleName in @('guest1', 'guest2', 'guest3')) {
        Start-Role $roles[$roleName]
        Wait-Stage { Test-Marker $roleName 'ready' } ('Eindeutiges echtes Haus und Bereitschaft: ' + $roleName)
    }
    Wait-Stage {
        foreach ($role in $roles.Values) { if (-not $role.Process.HasExited) { return $false } }
        return $true
    } 'Vier gleichzeitig verbundene Prozesse bestätigen Ausbauten, Welt und geordnetes Ende'
    $reports = [Collections.Generic.List[object]]::new()
    $pids = [Collections.Generic.HashSet[int]]::new()
    $peerIds = [Collections.Generic.HashSet[int]]::new()
    $worldHash = $null
    $goldJson = $null
    $developmentJson = $null
    $totalChecks = 0
    foreach ($roleName in $roleNames) {
        $role = $roles[$roleName]
        $role.Process.WaitForExit()
        if ($role.Process.ExitCode -ne 0) { throw "Rolle $roleName endete mit Exit $($role.Process.ExitCode)." }
        $report = Get-Content -LiteralPath (Join-Path $outputPath ($roleName + '-result.json')) -Raw -Encoding utf8 | ConvertFrom-Json
        if ($report.run_id -ne $runId -or $report.pid -ne $role.Process.Id -or $report.role -ne $roleName -or $report.version -ne $ExpectedVersion) { throw "Falsche Ergebnisidentität: $roleName" }
        if (-not $pids.Add([int]$report.pid) -or -not $peerIds.Add([int]$report.observed.local_peer_id)) { throw 'Die vier Nachweise besitzen keine vier eigenständigen Prozess- und Peerkennungen.' }
        if ($report.checks -lt 20 -or $report.failures.Count -ne 0 -or $report.observed.personal_house -ne $role.House) { throw "Unvollständiger Vier-Prozesse-Nachweis: $roleName" }
        if ($report.observed.month_index -ne 0 -or $report.observed.speed -ne 0 -or $report.observed.revision -ne 5) { throw "Unerlaubter Zeitfortschritt oder falsche Befehlsanzahl: $roleName" }
        $own = $report.observed.own_command
        if (-not $own.ack_ok -or $own.ack_count -ne 1 -or ($own.gold_before - $own.gold_after) -ne 50 -or ($own.development_after - $own.development_before) -ne 1) {
            throw "Eigenbefehl nicht genau einmal mit 50 Gold und echter Bestätigung ausgeführt: $roleName"
        }
        if ($report.observed.world_hash -notmatch '^[0-9a-f]{64}$') { throw "Echter Welthash fehlt: $roleName" }
        $thisGold = ConvertTo-Json -InputObject $report.observed.house_gold -Compress
        $thisDevelopment = ConvertTo-Json -InputObject $report.observed.capital_development -Compress
        if ($null -eq $worldHash) {
            $worldHash = $report.observed.world_hash
            $goldJson = $thisGold
            $developmentJson = $thisDevelopment
        } elseif ($worldHash -ne $report.observed.world_hash -or $goldJson -ne $thisGold -or $developmentJson -ne $thisDevelopment) {
            throw "Die vier Prozesse bestätigen keine identische tatsächliche Welt: $roleName"
        }
        $runtimeLog = Get-Content -LiteralPath $role.Log -Raw -Encoding utf8
        $allLogs = $runtimeLog + "`n" + $role.StdoutTask.Result + "`n" + $role.StderrTask.Result
        if ($allLogs -match '(?im)^\s*(ERROR|SCRIPT ERROR|FATAL|Unhandled|Exception|Crash)\b' -or $allLogs -match 'LAN_FOUR_PROCESS_SMOKE FAIL') { throw "Engine-/Testfehler in Rolle $roleName" }
        if ($allLogs -notmatch ('LAN_FOUR_PROCESS_SMOKE OK; role=' + $roleName)) { throw "Erfolgsmarker fehlt: $roleName" }
        $reports.Add($report)
        $totalChecks += $report.checks
    }
    foreach ($resource in $sourceHashes.Keys) {
        $relative = $resource.Substring('res://'.Length).Replace('/', '\')
        if ((Get-FileHash -LiteralPath (Join-Path $projectRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHashes[$resource]) { throw "Quellstand änderte sich während des Nachweises: $resource" }
    }
    if ((Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $engineHash) { throw 'Godot-EXE änderte sich während des Vier-Prozesse-Nachweises.' }
    $summary = [ordered]@{ stage = 'source-lan-four-process-smoke'; result = 'PASS'; run_id = $runId; version = $ExpectedVersion;
        engine = $godotPath; engine_sha256 = $engineHash; source_sha256 = $sourceHashes; port = $Port;
        process_ids = @($reports | ForEach-Object { $_.pid }); peer_ids = @($reports | ForEach-Object { $_.observed.local_peer_id });
        checks = $totalChecks; world_hash = $worldHash; isolated_profiles = $true; real_enet_processes = 4;
        all_four_houses_developed_once = $true; simulation_time_advanced = $false; explicit_test_fingerprint_override = $true;
        package_verified = $false; physical_android_wlan_test = $false; output = $outputPath }
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'summary.json') -Encoding utf8
    $succeeded = $true
    Write-Output ('LAN_FOUR_PROCESS_SOURCE_OK ' + ($summary | ConvertTo-Json -Compress -Depth 10))
} catch {
    [ordered]@{ stage = 'source-lan-four-process-smoke'; result = 'FAIL'; run_id = $runId; message = $_.Exception.Message;
        package_verified = $false; output = $outputPath } | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath (Join-Path $outputPath 'failure.json') -Encoding utf8
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
    if (-not $succeeded) { Write-Output ('Vier-Prozesse-Belege: ' + $outputPath) }
}
