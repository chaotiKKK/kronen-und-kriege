param(
    [ValidateSet('all', 'normal', 'mismatch', 'host_loss', 'guest_loss')]
    [string]$Case = 'all',
    [int]$Port = 0
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$godotPath = Join-Path $projectRoot '.tools\godot.exe'
$runRoot = Join-Path $projectRoot ('build\tests\lan-network\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$cases = if ($Case -eq 'all') { @('normal', 'mismatch', 'host_loss', 'guest_loss') } else { @($Case) }
$originalAppData = $env:APPDATA
$ownedProcesses = [Collections.Generic.List[Diagnostics.Process]]::new()
$summary = [Collections.Generic.List[object]]::new()

function Wait-Condition {
    param([scriptblock]$Condition, [int]$TimeoutSeconds, [string]$Description)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    }
    throw "Zeitüberschreitung: $Description"
}

function Stop-OwnedProcess {
    param([Diagnostics.Process]$Process)
    if ($Process -and -not $Process.HasExited) {
        $details = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $Process.Id)
        if ($details.ExecutablePath -ne $godotPath -or $details.CommandLine -notlike '*res://tests/LanTransportTest.tscn*') {
            throw "Prozess $($Process.Id) gehört nicht zu diesem Test."
        }
        Stop-Process -Id $Process.Id -Force
        $Process.WaitForExit(5000) | Out-Null
    }
}

try {
    foreach ($scenario in $cases) {
        $caseRoot = Join-Path $runRoot $scenario
        New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
        $testPort = $Port
        if ($testPort -eq 0) {
            $socket = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
            $testPort = $socket.Client.LocalEndPoint.Port
            $socket.Dispose()
        }
        if ($testPort -lt 49152 -or $testPort -gt 65535) { throw 'Testports müssen zwischen 49152 und 65535 liegen.' }
        $hostResult = Join-Path $caseRoot 'host.json'
        $guestResult = Join-Path $caseRoot 'guest.json'
        $roles = @{}
        foreach ($role in @('host', 'guest')) {
            $profile = Join-Path $caseRoot ($role + '-appdata')
            New-Item -ItemType Directory -Path $profile -Force | Out-Null
            $env:APPDATA = $profile
            $result = if ($role -eq 'host') { $hostResult } else { $guestResult }
            $arguments = @('--headless', '--path', ('"' + $projectRoot + '"'),
                'res://tests/LanTransportTest.tscn', '--', ('--lan-role=' + $role),
                ('--lan-port=' + $testPort), ('--lan-case=' + $scenario),
                ('"--lan-output=' + $result + '"'))
            $process = Start-Process -FilePath $godotPath -ArgumentList $arguments -WorkingDirectory $projectRoot `
                -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $caseRoot ($role + '.stdout.log')) `
                -RedirectStandardError (Join-Path $caseRoot ($role + '.stderr.log'))
            $ownedProcesses.Add($process)
            $roles[$role] = $process
            if ($role -eq 'host') {
                Wait-Condition { Test-Path -LiteralPath ($hostResult + '.ready') } 8 'Hostbereitschaft'
            }
        }
        if ($scenario -in @('host_loss', 'guest_loss')) {
            $victimRole = if ($scenario -eq 'host_loss') { 'host' } else { 'guest' }
            $victimResult = if ($victimRole -eq 'host') { $hostResult } else { $guestResult }
            Wait-Condition {
                if (-not (Test-Path -LiteralPath $victimResult)) { return $false }
                try { return (Get-Content -LiteralPath $victimResult -Raw | ConvertFrom-Json).ready_to_stop -eq $true } catch { return $false }
            } 18 'bestätigter Spielbefehl vor Prozessabbruch'
            Stop-OwnedProcess $roles[$victimRole]
        }
        foreach ($role in @('host', 'guest')) {
            if (($scenario -eq 'host_loss' -and $role -eq 'host') -or ($scenario -eq 'guest_loss' -and $role -eq 'guest')) { continue }
            $process = $roles[$role]
            if (-not $process.WaitForExit(25000)) { throw "Zeitüberschreitung: $scenario/$role" }
            $process.Refresh()
            if ($process.ExitCode -ne 0) { throw "Fehlgeschlagen: $scenario/$role, Exit $($process.ExitCode)" }
        }
        $hostData = Get-Content -LiteralPath $hostResult -Raw | ConvertFrom-Json
        $guestData = Get-Content -LiteralPath $guestResult -Raw | ConvertFrom-Json
        if ($hostData.failures -ne 0 -or $guestData.failures -ne 0) { throw "Fehlende Nachweise: $scenario" }
        foreach ($log in Get-ChildItem -LiteralPath $caseRoot -Filter '*.log') {
            if (Get-Content -LiteralPath $log.FullName | Select-String -Pattern 'SCRIPT ERROR|ERROR:|TEST FAIL') {
                throw "Engine- oder Testfehler in $($log.FullName)"
            }
        }
        $worldHash = $null
        if ($scenario -eq 'normal') {
            $hostWorld = Get-Content -LiteralPath ($hostResult + '.world') -Raw | ConvertFrom-Json
            $guestWorld = Get-Content -LiteralPath ($guestResult + '.world') -Raw | ConvertFrom-Json
            if ($hostWorld.hash -ne $guestWorld.hash -or $hostWorld.guest_gold -ne 80 -or $guestWorld.guest_gold -ne 80) {
                throw 'Die getrennten Prozesse bestätigten nicht dieselbe Welt und dieselben Kosten.'
            }
            $worldHash = $hostWorld.hash
        }
        $record = [ordered]@{ case = $scenario; result = 'PASS'; port = $testPort; host_pid = $roles['host'].Id;
            guest_pid = $roles['guest'].Id; checks = ($hostData.checks + $guestData.checks); world_hash = $worldHash }
        $summary.Add($record)
        Write-Output ($scenario + ': PASS, ' + $record.checks + ' Prüfungen, getrennte Prozesse und Profile')
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding utf8
    Write-Output ('Netzwerkbeleg: ' + $runRoot)
} finally {
    foreach ($process in $ownedProcesses) { Stop-OwnedProcess $process }
    $env:APPDATA = $originalAppData
}
