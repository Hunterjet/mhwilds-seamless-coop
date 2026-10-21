<#
.SYNOPSIS
  Downloads Ghidra 12.1.4 and the GhidraMCP 2.0 extension into C:\src\_tools (no admin needed).

.DESCRIPTION
  - Ghidra is extracted to C:\src\_tools\ghidra_12.1.4_PUBLIC (requires a JDK 21, installed by install-toolchain.ps1).
  - The GhidraMCP extension is unpacked into Ghidra's own Ghidra\Extensions folder (installed for all users of this
    Ghidra copy). After first launch, enable it in CodeBrowser: File > Configure > Developer > GhidraMCPPlugin.
  - The Python MCP bridge is installed separately into a venv by setup-mcp.ps1.
#>
param(
    [string]$ToolsDir = 'C:\src\_tools',
    [string]$DownloadDir = 'C:\src\.cache\downloads'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$headers = @{ 'User-Agent' = 'mhwilds-seamless-coop-setup' }
New-Item -ItemType Directory -Force -Path $ToolsDir, $DownloadDir | Out-Null

$ghidraZip = Join-Path $DownloadDir 'ghidra_12.1.4_PUBLIC_20260921.zip'
$ghidraUrl = 'https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip'
$mcpZip = Join-Path $DownloadDir 'GhidraMCP-release-2-0.zip'
$mcpUrl = 'https://github.com/LaurieWired/GhidraMCP/releases/download/2.0/GhidraMCP-release-2-0.zip'

foreach ($pair in @(@($ghidraUrl, $ghidraZip, 569649598), @($mcpUrl, $mcpZip, 238526))) {
    $url, $file, $size = $pair
    if (-not (Test-Path $file) -or (Get-Item $file).Length -ne $size) {
        Write-Host "Downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $file -Headers $headers -UseBasicParsing
    }
    if ((Get-Item $file).Length -ne $size) { throw "Size mismatch for $file" }
    Write-Host ("{0}  sha256={1}" -f (Split-Path $file -Leaf), (Get-FileHash $file -Algorithm SHA256).Hash)
}

$ghidraHome = Join-Path $ToolsDir 'ghidra_12.1.4_PUBLIC'
if (-not (Test-Path (Join-Path $ghidraHome 'ghidraRun.bat'))) {
    Write-Host "Extracting Ghidra to $ToolsDir"
    Expand-Archive -Path $ghidraZip -DestinationPath $ToolsDir -Force
}

$mcpDir = Join-Path $ToolsDir 'GhidraMCP-2.0'
Expand-Archive -Path $mcpZip -DestinationPath $mcpDir -Force
$extZip = Get-ChildItem $mcpDir -Recurse -Filter '*GhidraMCP*.zip' | Select-Object -First 1
if (-not $extZip) { throw 'GhidraMCP extension zip not found inside the release archive' }
Expand-Archive -Path $extZip.FullName -DestinationPath (Join-Path $ghidraHome 'Ghidra\Extensions') -Force
Write-Host "GhidraMCP extension unpacked from $($extZip.Name)"
Get-ChildItem (Join-Path $ghidraHome 'Ghidra\Extensions') -Directory | ForEach-Object { "  extension: $($_.Name)" }
Write-Host "Ghidra ready at $ghidraHome (run ghidraRun.bat; needs JDK 21)"
