param(
    [Parameter(Mandatory=$true)][ValidateSet('ProductionUiTest','ConstructionMapTest','ProductionCampaignTest','ProductionCommandTest')][string]$Suite,
    [Parameter(Mandatory=$true)][string]$Output,
    [switch]$Headless
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$outRoot=[IO.Path]::GetFullPath($Output)
$evidenceRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot 'build/verify'))+[IO.Path]::DirectorySeparatorChar
if (-not $outRoot.StartsWith($evidenceRoot,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $outRoot)) { throw 'Choose a fresh evidence directory below project/build/verify.' }
$work=Join-Path $outRoot 'empty-work'
$profile=Join-Path $outRoot 'profile'
New-Item -ItemType Directory -Path $work,$profile | Out-Null
$exe=Join-Path $projectRoot 'build/exports/banger-queens-1.9.1-production.exe'
$source=Join-Path $projectRoot ('tests/'+$Suite+'.gd')
$driver=Join-Path $outRoot ($Suite+'.gd')
$bootstrapSource=Join-Path $PSScriptRoot 'exported-campaign.gd.in'
$bootstrap=Join-Path $outRoot 'bootstrap.gd'
Copy-Item -LiteralPath $source -Destination $driver
Copy-Item -LiteralPath $bootstrapSource -Destination $bootstrap
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
$exeHash=Hash $exe
$driverHash=Hash $source
$bootstrapHash=Hash $bootstrapSource
$report=[ordered]@{passed=$false;suite=$Suite;exe=$exe;exe_sha256=$exeHash;source_driver_sha256=$driverHash;bootstrap_sha256=$bootstrapHash;headless=[bool]$Headless;started_utc=[DateTime]::UtcNow.ToString('o');scope='Actual exported embedded PCK, unchanged external driver, empty work directory, private profile; no source project mounted.'}
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$exe
$start.WorkingDirectory=$work
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$start.RedirectStandardOutput=$true
$start.RedirectStandardError=$true
$start.Environment['APPDATA']=$profile
$start.Environment['BQ_PRODUCTION_CAMPAIGN_PROOF']=$outRoot
$arguments=@('--path',$work,'--script',$bootstrap,'--resolution','1600x900','--position','1960,40','--log-file',(Join-Path $outRoot 'engine.log'))
if ($Headless) { $arguments+= '--headless' }
$arguments+=@('--',$driver,('--proof-dir='+$outRoot))
foreach ($argument in $arguments) { $start.ArgumentList.Add($argument) }
$process=[Diagnostics.Process]::new()
$process.StartInfo=$start
$failure=$null
try {
    $null=$process.Start()
    $report['pid']=$process.Id
    $stdoutTask=$process.StandardOutput.ReadToEndAsync()
    $stderrTask=$process.StandardError.ReadToEndAsync()
    $deadline=[DateTime]::UtcNow.AddSeconds(240)
    while (-not $process.WaitForExit(1000)) { if ([DateTime]::UtcNow -ge $deadline) { throw 'Bounded exported diagnostic timed out.' } }
    $stdout=$stdoutTask.GetAwaiter().GetResult()
    $stderr=$stderrTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $outRoot 'stdout.log'),$stdout)
    [IO.File]::WriteAllText((Join-Path $outRoot 'stderr.log'),$stderr)
    $combined=$stdout+$stderr
    $assertions=[regex]::Matches($combined,'(\d+) Prüfungen')
    if ($process.ExitCode -ne 0 -or $assertions.Count -eq 0 -or $combined -match 'SCRIPT ERROR|ERROR:|TEST FAIL') { throw 'Actual exported test failed; inspect preserved logs.' }
    $report['checks']=[int]$assertions[$assertions.Count-1].Groups[1].Value
    if ($report.checks -le 0) { throw 'Empty exported diagnostic.' }
    if ((Hash $exe) -ne $exeHash -or (Hash $source) -ne $driverHash -or (Hash $driver) -ne $driverHash -or (Hash $bootstrapSource) -ne $bootstrapHash -or (Hash $bootstrap) -ne $bootstrapHash) { throw 'Input bytes changed during exported diagnostic.' }
    $report['exit_code']=$process.ExitCode
    $report.passed=$true
    Write-Output ($Suite+' EXPORTED PASS '+$report.checks+' checks')
} catch { $failure=$_.Exception.Message } finally {
    if ($null -ne $report.pid -and -not $process.HasExited) { $process.Kill(); $null=$process.WaitForExit(5000) }
    $process.Dispose()
    $report['failure']=$failure
    $report['finished_utc']=[DateTime]::UtcNow.ToString('o')
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outRoot 'runtime-receipt.json') -Encoding utf8
}
if ($null -ne $failure) { throw $failure }
