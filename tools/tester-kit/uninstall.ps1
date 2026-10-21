<#
.SYNOPSIS
  Seamless Co-op tester kit: removes the research probe and restores the dinput8.dll that was there before the kit.
  Logs and save backups are kept (their folder is printed at the end).
#>
param([string]$GameDir, [string]$SteamDir, [switch]$NoPause)
$ErrorActionPreference = 'Stop'
$script:NoPause = $NoPause
. (Join-Path $PSScriptRoot 'kit-common.ps1')
trap { Stop-Kit ("Unexpected error: " + $_.Exception.Message + " (line " + $_.InvocationInfo.ScriptLineNumber + ")") }

Say "Seamless Co-op tester kit $KitVersion - uninstall" 'Cyan'
$game = Find-Game $GameDir $SteamDir
if ($null -eq $game -or -not (Test-Path -LiteralPath (Join-Path $game.Dir 'MonsterHunterWilds.exe'))) {
    Stop-Kit 'Could not find Monster Hunter Wilds. Run:  uninstall.cmd "<game folder>"'
}
Assert-GameClosed $game.Dir
Ensure-WriteAccess $game.Dir $PSCommandPath $PSBoundParameters

$data = Get-KitDataDir $game.Dir
$rfDir = Join-Path $game.Dir 'reframework'
$probe = Join-Path (Join-Path $rfDir 'autorun') 'seamless_probe.lua'
if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force; Say 'Removed the research probe.' 'Green' }
$modItems = @((Join-Path $rfDir 'autorun\seamless_coop.lua'), (Join-Path $rfDir 'autorun\seamless_coop'),
              (Join-Path $rfDir 'plugins\seamless_net.dll'))
$removedMod = $false
foreach ($item in $modItems) {
    if (Test-Path -LiteralPath $item) { Remove-Item -LiteralPath $item -Recurse -Force; $removedMod = $true }
}
if ($removedMod) { Say 'Removed the Seamless Co-op test build.' 'Green' }

# Use the OLDEST install manifest: it describes what was there before the kit was first installed.
$manifests = @(Get-ChildItem -LiteralPath $data -Filter 'install-*.json' -ErrorAction SilentlyContinue | Sort-Object Name)
if ($manifests.Count -eq 0) {
    Say 'No install record found; REFramework (dinput8.dll) was left as it is.' 'Yellow'
} else {
    $first = Get-Content -LiteralPath $manifests[0].FullName -Raw | ConvertFrom-Json
    $dinput = Join-Path $game.Dir 'dinput8.dll'
    if ($first.dinput8.existedBefore -and $first.dinput8.backup -and (Test-Path -LiteralPath $first.dinput8.backup)) {
        Copy-Item -LiteralPath $first.dinput8.backup -Destination $dinput -Force
        Say 'Restored your previous dinput8.dll.' 'Green'
    } elseif (-not $first.dinput8.existedBefore -and (Test-Path -LiteralPath $dinput)) {
        Remove-Item -LiteralPath $dinput -Force
        Say 'Removed REFramework (dinput8.dll), which was not there before the kit.' 'Green'
    } else {
        Say 'dinput8.dll left as it is.'
    }
}
Say ''
Say "Done. Logs and save backups are still in: $data"
Say 'You can delete that folder after sending your logs.'
if (-not $NoPause) { [void](Read-Host 'Press Enter to close this window') }
