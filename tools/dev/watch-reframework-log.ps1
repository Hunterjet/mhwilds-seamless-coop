<#
.SYNOPSIS
  Watches REFramework's log during a game launch and prints milestones (C# reference-assembly generation,
  plugin compilation, re-engine-mcp WebAPI) so a long first-run black screen can be told apart from a hang.

.EXAMPLE
  powershell -File tools\dev\watch-reframework-log.ps1 -WaitForStartMinutes 15 -MaxMinutes 25
#>
param(
    [string]$GameDir = 'C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds',
    [int]$WaitForStartMinutes = 15,
    [int]$MaxMinutes = 25
)
$log = Join-Path $GameDir 're2_framework_log.txt'
$patterns = 'Generating reference assemblies|Generating assembly|Successfully compiled|Wrote generated assembly|Loaded generated assembly|Loading generated assembly|Could not generate|error CS|\[WebAPI\]|Listening on|Unhandled exception|\[critical\]|Compil|plugin.*(fail|error)'
$t0 = Get-Date
function Stamp([string]$m) { "[{0:HH:mm:ss}] {1}" -f (Get-Date), $m }

Stamp "Waiting up to $WaitForStartMinutes min for MonsterHunterWilds.exe to start..."
$proc = $null
while (-not $proc -and ((Get-Date) - $t0).TotalMinutes -lt $WaitForStartMinutes) {
    $proc = Get-Process -Name MonsterHunterWilds -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) { Start-Sleep -Seconds 2 }
}
if (-not $proc) { Stamp 'Game did not start; giving up.'; exit 2 }
Stamp "Game started (pid $($proc.Id)). Following $log"

$seen = 0; $lastGrowth = Get-Date; $start = Get-Date
while (((Get-Date) - $start).TotalMinutes -lt $MaxMinutes) {
    Start-Sleep -Seconds 3
    $lines = @(Get-Content $log -ErrorAction SilentlyContinue)
    if ($lines.Count -lt $seen) { $seen = 0 }            # log was rotated by a relaunch
    if ($lines.Count -gt $seen) {
        $new = $lines[$seen..($lines.Count - 1)]; $seen = $lines.Count; $lastGrowth = Get-Date
        foreach ($l in $new) {
            if ($l -match $patterns) { Stamp ($l -replace '^\[[^\]]+\] \[REFramework\] ', '') }
            if ($l -match 'Listening on http') { Stamp 'MILESTONE: re-engine-mcp WebAPI is up.'; exit 0 }
        }
    }
    $alive = Get-Process -Name MonsterHunterWilds -ErrorAction SilentlyContinue
    if (-not $alive) {
        Start-Sleep -Seconds 5
        $alive = Get-Process -Name MonsterHunterWilds -ErrorAction SilentlyContinue
        if (-not $alive) { Stamp "Game process exited (log quiet for $([int]((Get-Date) - $lastGrowth).TotalSeconds)s)."; exit 3 }
    }
}
Stamp "Timeout after $MaxMinutes min; last log growth $([int]((Get-Date) - $lastGrowth).TotalSeconds)s ago."
exit 4
