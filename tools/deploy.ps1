<#
.SYNOPSIS
  Copies development builds into the game's REFramework folders. Writes ONLY inside <game>\reframework\.

.EXAMPLE
  tools\deploy.ps1 -Mod              # Lua mod (autorun\seamless_coop.lua + autorun\seamless_coop\) and seamless_net.dll
  tools\deploy.ps1 -Mod -LuaOnly     # Lua only; hot-reload in game: REFramework menu > ScriptRunner > Reset scripts
  tools\deploy.ps1 -Mod -Remove      # uninstall the mod (keeps reframework\data\seamless_coop: config, logs, backups)
  tools\deploy.ps1 -Probe            # install/update the read-only research probe (autorun\seamless_probe.lua)
  tools\deploy.ps1 -Probe -Remove    # uninstall it
.NOTES
  Build first: cmake --preset release; cmake --build --preset release (in a vcvars64 shell).
  The DLL is loaded at game start, so it can only be replaced while the game is closed.
#>
param(
    [switch]$Mod,
    [switch]$LuaOnly,
    [switch]$Probe,
    [switch]$Remove,
    [string]$BuildDir,
    [string]$GameDir = 'C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $BuildDir) { $BuildDir = Join-Path $repo 'build\release' }
if (-not (Test-Path (Join-Path $GameDir 'MonsterHunterWilds.exe'))) { throw "Monster Hunter Wilds not found in $GameDir" }
if (-not (Test-Path (Join-Path $GameDir 'dinput8.dll'))) { throw 'REFramework (dinput8.dll) is not installed in the game folder' }

$rf = Join-Path $GameDir 'reframework'
$autorun = Join-Path $rf 'autorun'
$plugins = Join-Path $rf 'plugins'
$traces = Join-Path $rf 'data\seamless_coop\traces'

function Test-GameRunning {
    $prefix = $GameDir.TrimEnd('\') + '\'
    foreach ($p in @(Get-Process -Name 'MonsterHunterWilds' -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $p.Path } catch { }
        if (-not $path -or $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

if (-not ($Mod -or $Probe)) { Write-Host 'Nothing to do: pass -Mod and/or -Probe.'; return }

if ($Probe) {
    $dst = Join-Path $autorun 'seamless_probe.lua'
    if ($Remove) {
        if (Test-Path $dst) { Remove-Item $dst -Force; Write-Host "Removed $dst" } else { Write-Host 'Probe not installed.' }
    } else {
        New-Item -ItemType Directory -Force -Path $autorun, $traces | Out-Null
        Copy-Item (Join-Path $repo 're\probes\seamless_probe.lua') $dst -Force
        Write-Host "Deployed probe -> $dst"
        Write-Host "Traces will be written to $traces"
    }
}

if ($Mod) {
    $entry = Join-Path $autorun 'seamless_coop.lua'
    $modDir = Join-Path $autorun 'seamless_coop'
    $dll = Join-Path $plugins 'seamless_net.dll'
    $pdb = Join-Path $plugins 'seamless_net.pdb'
    $touchDll = -not $LuaOnly
    if ($touchDll -and (Test-GameRunning)) {
        throw 'The game is running: seamless_net.dll is loaded and cannot be replaced. Close the game, or use -LuaOnly.'
    }
    if ($Remove) {
        foreach ($p in @($entry, $modDir) + $(if ($touchDll) { @($dll, $pdb) } else { @() })) {
            if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "Removed $p" }
        }
        Write-Host 'Kept reframework\data\seamless_coop (config, logs, save backups).'
        return
    }
    $srcDll = Join-Path $BuildDir 'src\plugin\seamless_net.dll'
    if ($touchDll -and -not (Test-Path $srcDll)) { throw "Build output not found: $srcDll (build first, or use -LuaOnly)" }

    New-Item -ItemType Directory -Force -Path $autorun | Out-Null
    if (Test-Path $modDir) { Remove-Item $modDir -Recurse -Force }
    Copy-Item (Join-Path $repo 'src\lua\seamless_coop') $modDir -Recurse
    Copy-Item (Join-Path $repo 'src\lua\seamless_coop.lua') $entry -Force
    $count = @(Get-ChildItem $modDir -Recurse -File).Count + 1
    Write-Host "Deployed Lua mod ($count files) -> $autorun"

    if ($touchDll) {
        New-Item -ItemType Directory -Force -Path $plugins | Out-Null
        Copy-Item $srcDll $dll -Force
        $srcPdb = [IO.Path]::ChangeExtension($srcDll, '.pdb')
        if (Test-Path $srcPdb) { Copy-Item $srcPdb $pdb -Force }
        Write-Host "Deployed seamless_net.dll -> $plugins"
    }
}
Write-Host 'In game: Insert > ScriptRunner > Reset scripts for Lua changes; restart the game for DLL changes.'
