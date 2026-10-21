<#
.SYNOPSIS
  Builds the tester kit zip: tools/tester-kit/* + re/probes/seamless_probe.lua + VERSION.txt.
.PARAMETER OutDir  Output folder (default C:\src\.cache\dist).
#>
param([string]$OutDir = 'C:\src\.cache\dist')
$ErrorActionPreference = 'Stop'
$kitDir = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $kitDir '..\..')).Path
. (Join-Path $kitDir 'kit-common.ps1')

$probe = Join-Path $repo 're\probes\seamless_probe.lua'
$probeVersion = ''
if ((Get-Content -LiteralPath $probe -Raw) -match 'local VERSION = "([^"]+)"') { $probeVersion = $Matches[1] }
$commit = (& git -C $repo rev-parse --short HEAD 2>$null)
$dirty = (& git -C $repo status --porcelain 2>$null)
if ($dirty) { $commit = "$commit+local-changes" }

$name = "seamless-coop-tester-kit-$KitVersion"
$stage = Join-Path $env:TEMP "$name-stage"
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$files = 'README-TESTER.md', 'SESSION-00.md', 'install.cmd', 'install.ps1', 'uninstall.cmd', 'uninstall.ps1',
         'collect-logs.cmd', 'collect-logs.ps1', 'kit-common.ps1'
foreach ($f in $files) { Copy-Item -LiteralPath (Join-Path $kitDir $f) -Destination $stage }
Copy-Item -LiteralPath $probe -Destination $stage

@(
    "Seamless Co-op tester kit $KitVersion"
    "Source commit: $commit"
    "Research probe: $probeVersion"
    "Game: Monster Hunter Wilds, Steam build $ExpectedBuild"
    "REFramework: $RefTag (dinput8.dll SHA-256 $RefDllSha256)"
    "Built (UTC): $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm'))"
) | Set-Content -LiteralPath (Join-Path $stage 'VERSION.txt') -Encoding ASCII

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$zip = Join-Path $OutDir "$name.zip"
New-ZipFromDir $stage $zip
Remove-Item -LiteralPath $stage -Recurse -Force

$sha = Get-Sha256 $zip
Write-Host "Built $zip"
Write-Host "  commit $commit, probe $probeVersion, SHA-256 $sha"
