<#
.SYNOPSIS
  Dumps type schemas from the live game (re-engine-mcp WebAPI on localhost:8899) and prints the members that match a
  keyword filter. Read-only: only GET /api/explorer/type is used.

.DESCRIPTION
  Full schemas are saved as JSON under .research-cache\typemap\ (gitignored: game-derived data must not be committed).
  The console output is compact ("ret signature" per matching method; "name : type" per matching field) so it can be
  pasted into notes or read by an agent without flooding its context.

.EXAMPLE
  tools\dev\re-typemap.ps1 -Types app.MissionManager,app.Net_Party -Filter 'sync|story|progress'
  tools\dev\re-typemap.ps1 -Types app.MissionManager -Filter '.' -NoFields      # every method
#>
param(
    [Parameter(Mandatory)] [string[]]$Types,
    [string]$Filter = '.',
    [switch]$NoFields,
    [switch]$NoMethods,
    [string]$Api = 'http://localhost:8899',
    [string]$OutDir = (Join-Path $PSScriptRoot '..\..\.research-cache\typemap')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
foreach ($t in $Types) {
    try {
        $r = Invoke-RestMethod -Uri ("$Api/api/explorer/type?typeName=" + [uri]::EscapeDataString($t)) -TimeoutSec 60
    } catch {
        "## $t : ERROR $($_.Exception.Message)"; continue
    }
    $r | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $OutDir (($t -replace '[^\w\.\-]', '_') + '.json')) -Encoding UTF8
    "## $t  (parent: $($r.parentType); fields: $($r.fieldCount); methods: $($r.methodCount))"
    if (-not $NoFields) {
        $r.fields | Where-Object { $_.name -match $Filter -or $_.typeName -match $Filter } | ForEach-Object {
            "  F {0}{1} : {2}" -f $(if ($_.isStatic) { 'static ' } else { '' }), $_.name, $_.typeName
        }
    }
    if (-not $NoMethods) {
        $r.methods | Where-Object { $_.signature -match $Filter } | ForEach-Object {
            "  M {0}  ->  {1}" -f $_.signature, ($_.returnType -replace '^System\.', '')
        }
    }
}
