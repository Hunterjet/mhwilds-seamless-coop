<#
.SYNOPSIS
  Packages the mod for release: <OutDir>\seamless-coop-<version>.zip with the layout
    reframework\autorun\seamless_coop.lua
    reframework\autorun\seamless_coop\**
    reframework\plugins\seamless_net.dll
    README.txt, LICENSE.txt
  (extract into the game folder, or install the zip with Fluffy Mod Manager).
.PARAMETER BuildDir  CMake build folder with seamless_net.dll (default build\release).
.PARAMETER OutDir    Output folder (default C:\src\.cache\dist).
.PARAMETER StageOnly Only create the staging folder (returned path) without zipping. Used by the tester kit builder.
#>
param([string]$BuildDir, [string]$OutDir = 'C:\src\.cache\dist', [switch]$StageOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $BuildDir) { $BuildDir = Join-Path $repo 'build\release' }

$versionLua = Get-Content (Join-Path $repo 'src\lua\seamless_coop\core\version.lua') -Raw
if ($versionLua -notmatch 'M\.mod = "([^"]+)"') { throw 'Cannot read the mod version from version.lua' }
$version = $Matches[1]
$dll = Join-Path $BuildDir 'src\plugin\seamless_net.dll'
if (-not (Test-Path $dll)) { throw "seamless_net.dll not found in $BuildDir (build first)" }
$newestSource = Get-ChildItem (Join-Path $repo 'src\plugin') -Recurse -File | Sort-Object LastWriteTime | Select-Object -Last 1
if ($newestSource.LastWriteTime -gt (Get-Item $dll).LastWriteTime) {
    throw "seamless_net.dll is older than $($newestSource.Name): rebuild first"
}

$name = "seamless-coop-$version"
$stage = Join-Path $env:TEMP "$name-stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
$autorun = Join-Path $stage 'reframework\autorun'
$plugins = Join-Path $stage 'reframework\plugins'
New-Item -ItemType Directory -Force -Path $autorun, $plugins | Out-Null
Copy-Item (Join-Path $repo 'src\lua\seamless_coop.lua') $autorun
Copy-Item (Join-Path $repo 'src\lua\seamless_coop') $autorun -Recurse
Copy-Item $dll $plugins
Copy-Item (Join-Path $repo 'LICENSE') (Join-Path $stage 'LICENSE.txt')
$commit = (& git -C $repo rev-parse --short HEAD 2>$null)
@(
    "Seamless Co-op for Monster Hunter Wilds $version (development build, commit $commit)"
    'https://github.com/Hunterjet/mhwilds-seamless-coop'
    ''
    'Requires REFramework (nightly-01433 tested) and Monster Hunter Wilds Steam build 24705561.'
    'Install: extract into the game folder (the folder with MonsterHunterWilds.exe), or install this zip with'
    'Fluffy Mod Manager. In game: Insert > Script Generated UI > Seamless Co-op.'
    'Uninstall: delete reframework\autorun\seamless_coop.lua, reframework\autorun\seamless_coop\ and'
    'reframework\plugins\seamless_net.dll. Settings, logs and save backups are in reframework\data\seamless_coop\.'
    ''
    'This build has no gameplay features yet: it shows party/mod status, makes save backups and tests the side channel.'
) | Set-Content (Join-Path $stage 'README.txt') -Encoding ASCII

if ($StageOnly) { return $stage }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$root = $stage.TrimEnd('\') + '\'
$archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    foreach ($f in Get-ChildItem $stage -Recurse -File) {
        $entry = $f.FullName.Substring($root.Length).Replace('\', '/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $entry,
            [System.IO.Compression.CompressionLevel]::Optimal)
    }
} finally {
    $archive.Dispose()
}
Remove-Item $stage -Recurse -Force
$sha = (Get-FileHash $zip -Algorithm SHA256).Hash
Write-Host "Packaged $zip"
Write-Host "  version $version, commit $commit, SHA-256 $sha"
