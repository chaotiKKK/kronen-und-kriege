param(
    [string]$Exe = "C:\Crusader Kings III\mobile-godot\.tools\godot.exe",
    [string]$Project = "C:\Crusader Kings III\mobile-godot",
    [string]$Mode = "acceptance",
    [string]$Out = "C:/Crusader Kings III/mobile-godot/build/verify/manual"
)
$ErrorActionPreference = "Stop"
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class AcceptanceWindow {
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
function Q([string]$value) { return '"' + $value + '"' }
$list = @()
if ($Project -ne "") {
    $list += "--path"
    $list += (Q $Project)
}
$list += "--"
$list += "--acceptance"
if ($Mode -ne "acceptance") { $list += "--$Mode" }
$list += ("--out=" + (Q $Out))
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$work = if ($Project -ne "") { $Project } else { "C:\Crusader Kings III" }
$p = Start-Process -FilePath $Exe -ArgumentList $list -WorkingDirectory $work `
    -WindowStyle Normal `
    -RedirectStandardOutput "$Out/run.out.log" -RedirectStandardError "$Out/run.err.log" -PassThru
# A minimized Godot window stops emitting frame_post_draw and stalls the
# screenshot checkpoints in the acceptance driver.
for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Milliseconds 200
    if ($p.HasExited) { break }
    $p.Refresh()
    if ($p.MainWindowHandle -ne 0) { break }
}
if (-not $p.HasExited -and $p.MainWindowHandle -ne 0) {
    [AcceptanceWindow]::ShowWindowAsync($p.MainWindowHandle, 9) | Out-Null
    [AcceptanceWindow]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
}
Write-Output $p.Id
