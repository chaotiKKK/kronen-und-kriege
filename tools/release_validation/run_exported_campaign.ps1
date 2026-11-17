param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$Output
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$verifyRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\verify'))
$outputPath = [IO.Path]::GetFullPath($Output)
if (-not $outputPath.StartsWith($verifyRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Output must stay in project build/verify.' }
if (Test-Path -LiteralPath $outputPath) { throw 'Choose a new output directory to preserve previous evidence.' }
$exePath = (Resolve-Path -LiteralPath $Exe).Path
if ([IO.Path]::GetExtension($exePath) -ne '.exe') { throw 'An exported EXE is required.' }
$testPath = Join-Path $projectRoot 'tests\NavalExpeditionTest.gd'
$bootstrapPath = Join-Path $PSScriptRoot 'exported-campaign.gd.in'
New-Item -ItemType Directory -Path $outputPath | Out-Null
$driver = Join-Path $outputPath 'campaign.gd'
$bootstrap = Join-Path $outputPath 'bootstrap.gd'
Copy-Item -LiteralPath $testPath -Destination $driver
Copy-Item -LiteralPath $bootstrapPath -Destination $bootstrap
$work = Join-Path $outputPath 'empty-work'
$profile = Join-Path $outputPath 'profile'
New-Item -ItemType Directory -Path $work,$profile | Out-Null
$log = Join-Path $outputPath 'engine.log'
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $exePath
$start.Arguments = '--headless --path "{0}" --script "{1}" --log-file "{2}" -- "{3}" "--proof-dir={4}"' -f $work,$bootstrap,$log,$driver,$outputPath
$start.WorkingDirectory = $work
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.EnvironmentVariables['APPDATA'] = $profile
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
$record = [ordered]@{
    format='banger-queens-exported-campaign/v1'; passed=$false
    exe=$exePath;exe_sha256=(Hash $exePath);driver_source=$testPath;driver_sha256=(Hash $testPath)
    bootstrap_sha256=(Hash $bootstrapPath);working_directory=$work;arguments=$start.Arguments
    started_utc=[DateTime]::UtcNow.ToString('o');pid=$null;exit_code=$null;checks=0
    scope='Real exported PCK game, external unchanged fixed-seed campaign driver. Headless; no Main/GPU/Android or full balance acceptance.'
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $start
$caught = $null
$stdoutTask = $null
$stderrTask = $null
try {
    if (-not $process.Start()) { throw 'Could not start exported campaign.' }
    $record.pid = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    # Bounded test observation, not a limit on normal game loading.
    if (-not $process.WaitForExit(120000)) { throw 'Exported campaign probe exceeded its two-minute observation window.' }
    $record.exit_code = $process.ExitCode
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $outputPath 'stdout.log'),$stdout)
    [IO.File]::WriteAllText((Join-Path $outputPath 'stderr.log'),$stderr)
    $count = [regex]::Match($stdout,'NAVALEXPEDITIONTEST OK: (\d+) Prüfungen')
    if ($count.Success) { $record.checks = [int]$count.Groups[1].Value }
    $campaign = Get-Content -LiteralPath (Join-Path $outputPath 'campaign.json') -Raw | ConvertFrom-Json
    if ($process.ExitCode -ne 0 -or $record.checks -le 0 -or ($stdout+$stderr) -match 'SCRIPT ERROR|ERROR:|TEST FAIL') { throw 'Exported campaign reported failure; inspect preserved logs.' }
    if ($campaign.seed -ne 20261117 -or $campaign.changed_npc_count -ne 8 -or $campaign.landed_month -le 0 -or $campaign.conquered_month -le $campaign.landed_month) { throw 'Exported campaign did not meet its ordinary-play contract.' }
    if ((Hash $testPath) -ne $record.driver_sha256 -or (Hash $driver) -ne $record.driver_sha256 -or (Hash $exePath) -ne $record.exe_sha256) { throw 'Input bytes changed during packaged verification.' }
    $record.passed = $true
    $record.campaign_sha256 = Hash (Join-Path $outputPath 'campaign.json')
    $record.landed_month = $campaign.landed_month
    $record.conquered_month = $campaign.conquered_month
} catch { $caught = $_.Exception.Message } finally {
    if ($null -ne $record.pid -and -not $process.HasExited) { $process.Kill(); $null=$process.WaitForExit(5000) }
    if ($null -ne $record.pid -and $process.HasExited) { $record.exit_code=$process.ExitCode }
    foreach ($stream in @(@('stdout',$stdoutTask),@('stderr',$stderrTask))) {
        if ($null -ne $stream[1] -and $stream[1].Wait(5000)) {
            [IO.File]::WriteAllText((Join-Path $outputPath ($stream[0]+'.log')),$stream[1].Result)
        }
    }
    $record.ended_utc = [DateTime]::UtcNow.ToString('o')
    $record.failure = $caught
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputPath 'receipt.json') -Encoding utf8
}
if ($null -ne $caught) { throw $caught }
$record | ConvertTo-Json -Depth 4
