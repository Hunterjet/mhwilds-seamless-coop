<#
.SYNOPSIS
  Runs the portable GitHub CLI with its config/state kept under <dev root>\.cache\gh instead of the user profile.

.DESCRIPTION
  Dev root defaults to C:\src (override with $env:SEAMLESS_DEV_ROOT). gh itself lives in <dev root>\_tools\gh.
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
& (Join-Path $root '_tools\gh\bin\gh.exe') @args
exit $LASTEXITCODE
