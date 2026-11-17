param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string]$Output,
    [switch]$IncludeUi,
    [switch]$UiOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$verifyRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build\verify'))
$outputPath = [IO.Path]::GetFullPath($Output)
if (-not $outputPath.StartsWith($verifyRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Output must stay in this project build/verify.' }
if (Test-Path -LiteralPath $outputPath) { throw 'Use a fresh output directory to preserve evidence.' }
$exePath = (Resolve-Path -LiteralPath $Exe).Path
if ([IO.Path]::GetExtension($exePath) -ne '.exe') { throw 'An actual exported EXE is required.' }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
New-Item -ItemType Directory -Path $outputPath | Out-Null
$exeHash = Hash $exePath
$bootstrapSource = Join-Path $PSScriptRoot 'exported-campaign.gd.in'
$bootstrapHash = Hash $bootstrapSource
$cases = @('FortressCampaignTest','FortressCampaignCommandTest','FortressCampaignAiTest','FortressEdgeTest')
if ($UiOnly) { $cases = @('FortressCampaignUiTest') }
elseif ($IncludeUi) { $cases += 'FortressCampaignUiTest' }
$position = $null
if ($IncludeUi -or $UiOnly) {
    Add-Type -AssemblyName System.Windows.Forms
    $rightScreen = [Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.Right } | Select-Object -Last 1
    $position = '{0},{1}' -f ($rightScreen.Bounds.Left+40),($rightScreen.Bounds.Top+40)
}
$report = [ordered]@{
    format='banger-queens-campaign-package/v1';passed=$false;exe=$exePath;exe_sha256=$exeHash
    bootstrap_sha256=$bootstrapHash;checks=0;cases=@();started_utc=[DateTime]::UtcNow.ToString('o')
    scope='Real exported PCK game/GUI and ENet with unchanged external controlled test drivers. Separate from ordinary campaign budgets and physical Android validation.'
}
$failed = $null
try {
    foreach ($case in $cases) {
        $caseRoot = Join-Path $outputPath $case
        $work = Join-Path $caseRoot 'empty-work'
        $profile = Join-Path $caseRoot 'profile'
        New-Item -ItemType Directory -Path $work,$profile | Out-Null
        $source = Join-Path $projectRoot ('tests\'+$case+'.gd')
        $sourceHash = Hash $source
        $driver = Join-Path $caseRoot 'driver.gd'
        $bootstrap = Join-Path $caseRoot 'bootstrap.gd'
        Copy-Item -LiteralPath $source -Destination $driver
        Copy-Item -LiteralPath $bootstrapSource -Destination $bootstrap
        $log = Join-Path $caseRoot 'engine.log'
        $uiCase = $case -eq 'FortressCampaignUiTest'
        $displayArgs = if ($uiCase) { '--resolution 1600x900 --position '+$position } else { '--headless' }
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $exePath
        $start.Arguments = '{0} --path "{1}" --script "{2}" --log-file "{3}" -- "{4}"' -f $displayArgs,$work,$bootstrap,$log,$driver
        $start.WorkingDirectory = $work
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $start.EnvironmentVariables['APPDATA'] = $profile
        $record = [ordered]@{name=$case;passed=$false;checks=0;source_sha256=$sourceHash;arguments=$start.Arguments;pid=$null;exit_code=$null;windowed=$uiCase}
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $start
        try {
            if (-not $process.Start()) { throw 'Could not start exported test.' }
            $record.pid = $process.Id
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(180000)) { throw 'Controlled package check exceeded its bounded observation window.' }
            $record.exit_code = $process.ExitCode
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            [IO.File]::WriteAllText((Join-Path $caseRoot 'stdout.log'),$stdout)
            [IO.File]::WriteAllText((Join-Path $caseRoot 'stderr.log'),$stderr)
            $count = [regex]::Match($stdout,'TEST OK: (\d+) Prüfungen')
            if ($count.Success) { $record.checks = [int]$count.Groups[1].Value }
            if ($process.ExitCode -ne 0 -or $record.checks -le 0 -or ($stdout+$stderr) -match 'SCRIPT ERROR|ERROR:|TEST FAIL') { throw ($case+' failed; inspect preserved logs.') }
            if ((Hash $source) -ne $sourceHash -or (Hash $driver) -ne $sourceHash -or (Hash $exePath) -ne $exeHash) { throw 'Package or driver changed during verification.' }
            $record.passed = $true
            $report.checks += $record.checks
            Write-Output ($case+' PASS '+$record.checks)
        } finally {
            if ($null -ne $record.pid -and -not $process.HasExited) { $process.Kill(); $null=$process.WaitForExit(5000) }
            $report.cases += $record
            $process.Dispose()
        }
    }
    if ((Hash $bootstrapSource) -ne $bootstrapHash) { throw 'Bootstrap source changed during verification.' }
    $report.passed = $true
} catch { $failed=$_.Exception.Message } finally {
    $report['finished_utc']=[DateTime]::UtcNow.ToString('o')
    $report['failure']=$failed
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $outputPath 'receipt.json') -Encoding utf8
}
if ($null -ne $failed) { throw $failed }
Write-Output ('CAMPAIGN_PACKAGE OK '+$report.checks+' checks; '+$outputPath)
