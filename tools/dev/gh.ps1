<#
.SYNOPSIS
  Runs GitHub CLI with its config/state kept under <dev root>\.cache\gh instead of the user profile.

.DESCRIPTION
  Uses the system-wide install (C:\Program Files\GitHub CLI\gh.exe) when present, else a portable copy in
  <dev root>\_tools\gh. Dev root defaults to C:\src (override with $env:SEAMLESS_DEV_ROOT).
  The login token is stored by gh in the OS keyring (Windows Credential Manager).

.EXAMPLE
  tools\dev\gh.ps1 auth status
  tools\dev\gh.ps1 release list
#>
$root = if ($env:SEAMLESS_DEV_ROOT) { $env:SEAMLESS_DEV_ROOT } else { 'C:\src' }
$env:GH_CONFIG_DIR = Join-Path $root '.cache\gh\config'
$env:XDG_STATE_HOME = Join-Path $root '.cache\gh\state'
$env:XDG_DATA_HOME = Join-Path $root '.cache\gh\data'
$env:XDG_CACHE_HOME = Join-Path $root '.cache\gh\cache'
$env:GH_NO_UPDATE_NOTIFIER = '1'
$env:GH_NO_EXTENSION_UPDATE_NOTIFIER = '1'
$gh = Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'
if (-not (Test-Path $gh)) { $gh = Join-Path $root '_tools\gh\bin\gh.exe' }
& $gh @args
exit $LASTEXITCODE
