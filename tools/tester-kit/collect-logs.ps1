<#
.SYNOPSIS
  Seamless Co-op tester kit: puts the research logs into one zip file (on the Desktop by default) to send to the
  developer. Personal details are removed: the Windows user name and full Steam IDs are replaced in text files.
.PARAMETER OutDir  Where to write the zip (default: Desktop).
#>
param([string]$GameDir, [string]$SteamDir, [string]$OutDir, [switch]$NoPause)
$ErrorActionPreference = 'Stop'
$script:NoPause = $NoPause
. (Join-Path $PSScriptRoot 'kit-common.ps1')
trap { Stop-Kit ("Unexpected error: " + $_.Exception.Message + " (line " + $_.InvocationInfo.ScriptLineNumber + ")") }

Say "Seamless Co-op tester kit $KitVersion - collect logs" 'Cyan'
$game = Find-Game $GameDir $SteamDir
if ($null -eq $game -or -not (Test-Path -LiteralPath (Join-Path $game.Dir 'MonsterHunterWilds.exe'))) {
    Stop-Kit 'Could not find Monster Hunter Wilds. Run:  collect-logs.cmd "<game folder>"'
}
$data = Get-KitDataDir $game.Dir
$stamp = Get-Stamp
$staging = Join-Path $env:TEMP "seamless-coop-logs-$stamp"
New-Item -ItemType Directory -Force -Path $staging | Out-Null

$files = @()
$files += @(Get-ChildItem -LiteralPath (Join-Path $data 'traces') -Filter '*.jsonl' -ErrorAction SilentlyContinue)
$files += @(Get-ChildItem -LiteralPath (Join-Path $data 'logs') -Filter '*.log' -ErrorAction SilentlyContinue)
$files += @(Get-ChildItem -LiteralPath $data -Filter 'install-*.json' -ErrorAction SilentlyContinue)
foreach ($n in 'diagnostics.json', 'config.json') {
    $p = Join-Path $data $n
    if (Test-Path -LiteralPath $p) { $files += @(Get-Item -LiteralPath $p) }
}
foreach ($n in 're2_framework_log.txt', 're2_framework_log.prev.txt') {
    $p = Join-Path $game.Dir $n
    if (Test-Path -LiteralPath $p) { $files += @(Get-Item -LiteralPath $p) }
}
if ($files.Count -eq 0) { Stop-Kit 'No logs found yet. Play a session with the probe installed first.' }

foreach ($f in $files) {
    # Shared read: the game may still have a trace open.
    $fs = [System.IO.File]::Open($f.FullName, 'Open', 'Read', 'ReadWrite')
    $sr = New-Object System.IO.StreamReader($fs)
    $text = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
    $text = Protect-LogText $text
    [System.IO.File]::WriteAllText((Join-Path $staging $f.Name), $text, (New-Object System.Text.UTF8Encoding($false)))
}

if (-not $OutDir) { $OutDir = [Environment]::GetFolderPath('Desktop') }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$zip = Join-Path $OutDir "seamless-coop-logs-$stamp.zip"
New-ZipFromDir $staging $zip
Remove-Item -LiteralPath $staging -Recurse -Force

Say ''
Say "Created: $zip" 'Green'
Say "It contains $($files.Count) file(s). Please send this file to the developer."
if (-not $NoPause) { [void](Read-Host 'Press Enter to close this window') }
