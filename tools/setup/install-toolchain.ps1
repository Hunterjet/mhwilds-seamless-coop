<#
.SYNOPSIS
  Installs the Seamless Co-op development toolchain with winget. Safe to re-run (already-installed packages are skipped/upgraded).

.DESCRIPTION
  Visual Studio 2022 Build Tools (C++ workload), CMake, Ninja, Python 3.13, .NET 10 SDK, lua-language-server, clangd,
  Microsoft OpenJDK 21 (for Ghidra). Prefers machine scope so nothing is installed under the user profile.
  Run from an elevated PowerShell (or let the script relaunch itself elevated).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\setup\install-toolchain.ps1
#>
param(
    [string]$LogPath = 'C:\src\.cache\logs\toolchain-install.log'
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-LogPath', "`"$LogPath`"")
    exit $LASTEXITCODE
}

New-Item -ItemType Directory -Force -Path (Split-Path $LogPath) | Out-Null
function Log([string]$msg) { "[{0:u}] {1}" -f (Get-Date), $msg | Tee-Object -FilePath $LogPath -Append }

$packages = @(
    @{ Id = 'Microsoft.VisualStudio.2022.BuildTools'
       Override = '--passive --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended' },
    @{ Id = 'Kitware.CMake' },
    @{ Id = 'Ninja-build.Ninja' },
    @{ Id = 'Python.Python.3.13' },
    @{ Id = 'Microsoft.DotNet.SDK.10' },
    @{ Id = 'LuaLS.lua-language-server' },
    @{ Id = 'LLVM.clangd' },
    @{ Id = 'Microsoft.OpenJDK.21' }
)

$common = @('-e', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
$NO_APPLICABLE_INSTALLER = -1978335216  # 0x8A150010

Log "Toolchain install started"
foreach ($p in $packages) {
    $tail = [string[]]$(if ($p.Override) { '--override', $p.Override } else { '--silent' })
    Log "Installing $($p.Id) (machine scope)"
    winget install --id $p.Id @common --scope machine @tail *>> $LogPath
    $code = $LASTEXITCODE
    if ($code -eq $NO_APPLICABLE_INSTALLER) {
        Log "  no machine-scope installer for $($p.Id); retrying with the package default scope"
        winget install --id $p.Id @common @tail *>> $LogPath
        $code = $LASTEXITCODE
    }
    Log "  $($p.Id) -> exit code $code"
}
Log "Toolchain install finished"
