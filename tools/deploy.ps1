<#
.SYNOPSIS
  Copies development builds into the game's REFramework folders. Writes ONLY inside <game>\reframework\.

.EXAMPLE
  tools\deploy.ps1 -Probe            # install/update the read-only research probe (autorun\seamless_probe.lua)
  tools\deploy.ps1 -Probe -Remove    # uninstall it
.NOTES
  After deploying Lua, press "Reset scripts" in the REFramework menu (Insert key > ScriptRunner) or restart the game.
#>
param(
    [switch]$Probe,
    [switch]$Remove,
    [string]$GameDir = 'C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $GameDir 'MonsterHunterWilds.exe'))) { throw "Monster Hunter Wilds not found in $GameDir" }
if (-not (Test-Path (Join-Path $GameDir 'dinput8.dll'))) { throw 'REFramework (dinput8.dll) is not installed in the game folder' }

$rf = Join-Path $GameDir 'reframework'
$autorun = Join-Path $rf 'autorun'
$traces = Join-Path $rf 'data\seamless_coop\traces'

if (-not $Probe) { Write-Host 'Nothing to do: pass -Probe (more targets will be added with the mod).'; return }

$dst = Join-Path $autorun 'seamless_probe.lua'
if ($Remove) {
    if (Test-Path $dst) { Remove-Item $dst -Force; Write-Host "Removed $dst" } else { Write-Host 'Probe not installed.' }
    return
}
New-Item -ItemType Directory -Force -Path $autorun, $traces | Out-Null
Copy-Item (Join-Path $repo 're\probes\seamless_probe.lua') $dst -Force
Write-Host "Deployed probe -> $dst"
Write-Host "Traces will be written to $traces"
Write-Host 'In game: Insert > ScriptRunner > Reset scripts (or restart the game).'
