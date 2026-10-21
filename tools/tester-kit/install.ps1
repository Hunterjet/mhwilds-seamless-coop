<#
.SYNOPSIS
  Seamless Co-op tester kit: installs the pinned REFramework build and the read-only research probe for
  Monster Hunter Wilds. Backs up everything it replaces. Never edits game data or save files.
.PARAMETER GameDir   Use this game folder instead of detecting it through Steam.
.PARAMETER SteamDir  Use this Steam folder (for the version check and save backup) instead of detecting it.
.PARAMETER ZipPath   Use an already-downloaded REFramework.zip instead of downloading it.
.PARAMETER NoPause   Do not wait for Enter at the end (for automated runs).
#>
param([string]$GameDir, [string]$SteamDir, [string]$ZipPath, [switch]$NoPause)
$ErrorActionPreference = 'Stop'
$script:NoPause = $NoPause
. (Join-Path $PSScriptRoot 'kit-common.ps1')
trap { Stop-Kit ("Unexpected error: " + $_.Exception.Message + " (line " + $_.InvocationInfo.ScriptLineNumber + ")") }

Say "Seamless Co-op tester kit $KitVersion - install" 'Cyan'
Say 'This installs REFramework and a READ-ONLY research script. It does not change your saves or the game.'
Say ''

$game = Find-Game $GameDir $SteamDir
if ($null -eq $game) {
    Stop-Kit ("Could not find Monster Hunter Wilds. In Steam: right-click the game > Manage > Browse local files, " +
              "copy that folder path, then run:  install.cmd ""<that folder>""")
}
$exe = Join-Path $game.Dir 'MonsterHunterWilds.exe'
if (-not (Test-Path -LiteralPath $exe)) { Stop-Kit "MonsterHunterWilds.exe not found in $($game.Dir)" }
Say "Game folder: $($game.Dir)"
Assert-GameClosed $game.Dir

if ($game.Build -and $game.Build -ne $ExpectedBuild) {
    Stop-Kit ("Your game version (Steam build $($game.Build)) is different from the version this kit was made for " +
              "($ExpectedBuild). Please tell the developer; a new kit is needed.")
}
if (-not $game.Build) { Say 'Note: could not read the game version from Steam; continuing.' 'Yellow' }

Ensure-WriteAccess $game.Dir $PSCommandPath $PSBoundParameters

$stamp = Get-Stamp
$data = Get-KitDataDir $game.Dir
$backupDir = Join-Path (Join-Path $data 'backups') $stamp
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

# 1) Back up the existing dinput8.dll (REFramework or anything else using that name)
$dinput = Join-Path $game.Dir 'dinput8.dll'
$hadDinput = Test-Path -LiteralPath $dinput
$prevSha = $null
if ($hadDinput) {
    $prevSha = Get-Sha256 $dinput
    Copy-Item -LiteralPath $dinput -Destination (Join-Path $backupDir 'dinput8.dll') -Force
    Say "Backed up your current dinput8.dll."
}

# 2) Back up save data (copy only)
$saveCopies = @()
if ($game.SteamDir) {
    $userdata = Join-Path $game.SteamDir 'userdata'
    if (Test-Path -LiteralPath $userdata) {
        foreach ($acct in Get-ChildItem -LiteralPath $userdata -Directory -ErrorAction SilentlyContinue) {
            $remote = Join-Path (Join-Path $acct.FullName $AppId) 'remote'
            if (Test-Path -LiteralPath $remote) {
                $dst = Join-Path (Join-Path (Join-Path $data 'kit_save_backups') $stamp) ('account-' + $acct.Name.Substring([Math]::Max(0, $acct.Name.Length - 4)))
                New-Item -ItemType Directory -Force -Path $dst | Out-Null
                Copy-Item -Path (Join-Path $remote '*') -Destination $dst -Recurse -Force
                $saveCopies += $dst
            }
        }
    }
}
if ($saveCopies.Count -gt 0) { Say "Copied your save files to a backup folder ($($saveCopies.Count) account(s))." }
else { Say 'Note: no save folder found to back up (this is fine if you play on another Steam folder).' 'Yellow' }

# 3) REFramework (pinned build)
$installedRef = $false
if ($hadDinput -and $prevSha -eq $RefDllSha256) {
    Say 'REFramework (the right version) is already installed.'
} else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $zip = $ZipPath
    if (-not $zip) {
        $zip = Join-Path $env:TEMP "seamless-coop-REFramework-$stamp.zip"
        Say 'Downloading REFramework (about 13 MB)...'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $RefZipUrl -OutFile $zip -UseBasicParsing
    }
    $zipSha = Get-Sha256 $zip
    if ($zipSha -ne $RefZipSha256) { Stop-Kit "The REFramework download did not match the expected checksum. Nothing was changed." }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $entry = $archive.Entries | Where-Object { $_.FullName -eq 'dinput8.dll' } | Select-Object -First 1
        if ($null -eq $entry) { Stop-Kit 'dinput8.dll is missing from the REFramework download.' }
        $tmpDll = Join-Path $env:TEMP "seamless-coop-dinput8-$stamp.dll"
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tmpDll, $true)
    } finally { $archive.Dispose() }
    if ((Get-Sha256 $tmpDll) -ne $RefDllSha256) { Stop-Kit 'Unexpected REFramework file contents. Nothing was changed.' }
    Copy-Item -LiteralPath $tmpDll -Destination $dinput -Force
    Remove-Item -LiteralPath $tmpDll -Force
    if (-not $ZipPath) { Remove-Item -LiteralPath $zip -Force }
    $installedRef = $true
    Say 'Installed REFramework.' 'Green'
}

# 4) Research probe (read-only Lua script)
$autorun = Join-Path (Join-Path $game.Dir 'reframework') 'autorun'
New-Item -ItemType Directory -Force -Path $autorun, (Join-Path $data 'traces') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'seamless_probe.lua') -Destination (Join-Path $autorun 'seamless_probe.lua') -Force
Say 'Installed the research probe.' 'Green'

# 5) Seamless Co-op test build (status panel, save backup at each launch, side-channel test; no gameplay changes)
$modFiles = 0
$modSrc = Join-Path (Join-Path $PSScriptRoot 'mod') 'reframework'
if (Test-Path -LiteralPath $modSrc) {
    $oldModDir = Join-Path $autorun 'seamless_coop'
    if (Test-Path -LiteralPath $oldModDir) { Remove-Item -LiteralPath $oldModDir -Recurse -Force }
    $modFiles = Copy-Tree $modSrc (Join-Path $game.Dir 'reframework')
    $cfg = Join-Path $data 'config.json'
    if (-not (Test-Path -LiteralPath $cfg)) {
        # Test builds check their own connection through Steam once per launch (one line in the mod's log).
        Set-Content -LiteralPath $cfg -Value '{ "dev_selftest": true }' -Encoding ASCII
    }
    Say 'Installed the Seamless Co-op test build.' 'Green'
}

# 6) Manifest for uninstall/support
$manifest = [ordered]@{
    kit = $KitVersion; installedUtc = $stamp; gameBuild = $game.Build
    dinput8 = [ordered]@{ existedBefore = $hadDinput; previousSha256 = $prevSha; replaced = $installedRef; backup = $(if ($hadDinput) { Join-Path $backupDir 'dinput8.dll' } else { $null }) }
    saveBackups = $saveCopies
    probe = (Join-Path $autorun 'seamless_probe.lua')
    modFiles = $modFiles
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $data "install-$stamp.json") -Encoding UTF8

Say ''
Say 'All done!' 'Green'
Say 'Next: start Monster Hunter Wilds from Steam as usual. In the game, press Insert to open the REFramework menu, open'
Say '"Script Generated UI": "Seamless Co-op probe" should say "Hooks: ... ok", and "Seamless Co-op" should say'
Say '"Game build: 24705561 (verified)". Press Insert again to close the menu.'
if (-not $NoPause) { [void](Read-Host 'Press Enter to close this window') }
