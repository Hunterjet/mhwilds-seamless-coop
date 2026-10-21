# Shared helpers for the Seamless Co-op tester kit. Dot-sourced by install.ps1, uninstall.ps1 and collect-logs.ps1.
# Must run on Windows PowerShell 5.1 (no PowerShell 7-only syntax).

$KitVersion = 'v0.2'
$AppId = '2246340'
$ExpectedBuild = '24705561'      # Steam build of Monster Hunter Wilds this kit was tested with
$RefTag = 'nightly-01433-d4611aef1d63effd3a736bdf9404ea702428017d'
$RefZipUrl = "https://github.com/praydog/REFramework-nightly/releases/download/$RefTag/REFramework.zip"
$RefZipSha256 = 'B3FF4F497BE6F108EF494C2C02156B61B8D04F3171378ECC0DC28C218EE296B3'
$RefDllSha256 = 'CB1ACC11BE71184BE1EB5C29CCEA2DB156A55EEE861686B71BBC522865D2C98A'

function Say([string]$Message, [string]$Color = 'Gray') { Write-Host $Message -ForegroundColor $Color }

# Exit code 2 = handled stop (the .cmd launchers pause only on other non-zero codes, e.g. a crash).
function Stop-Kit([string]$Message) {
    Say ''
    Say "STOPPED: $Message" 'Red'
    if (-not $script:NoPause) { [void](Read-Host 'Press Enter to close this window') }
    exit 2
}

function Normalize-Dir([string]$Dir) {
    if (-not $Dir) { return $Dir }
    return $Dir.Trim().Trim('"').TrimEnd('\')
}

function Find-SteamDir {
    $keys = 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam'
    foreach ($k in $keys) {
        $p = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
        if ($null -eq $p) { continue }
        foreach ($n in 'SteamPath', 'InstallPath') {
            $v = $p.$n
            if ($v -and (Test-Path -LiteralPath $v)) { return (Resolve-Path -LiteralPath $v).Path }
        }
    }
    return $null
}

# Returns @{ InstallDir; Build } from a Steam appmanifest_<AppId>.acf file, or $null.
function Read-AppManifest([string]$Acf) {
    if (-not (Test-Path -LiteralPath $Acf)) { return $null }
    $txt = Get-Content -LiteralPath $Acf -Raw
    $info = @{ InstallDir = 'MonsterHunterWilds'; Build = '' }
    if ($txt -match '"installdir"\s+"([^"]+)"') { $info.InstallDir = $Matches[1] }
    if ($txt -match '"buildid"\s+"(\d+)"') { $info.Build = $Matches[1] }
    return $info
}

# Returns @{ Dir; Build; SteamDir } or $null. $GameDirOverride skips detection; its build comes from the manifest of
# the Steam library that contains it (<library>\steamapps\common\<game> -> <library>\steamapps\appmanifest_*.acf).
function Find-Game([string]$GameDirOverride, [string]$SteamDirOverride) {
    $GameDirOverride = Normalize-Dir $GameDirOverride
    $steam = Normalize-Dir $SteamDirOverride
    if (-not $steam) { $steam = Find-SteamDir }
    if ($GameDirOverride) {
        $steamapps = Split-Path (Split-Path $GameDirOverride -Parent) -Parent
        $info = Read-AppManifest (Join-Path $steamapps "appmanifest_$AppId.acf")
        $build = ''
        if ($info) { $build = $info.Build }
        return @{ Dir = $GameDirOverride; Build = $build; SteamDir = $steam }
    }
    if (-not $steam) { return $null }
    $libs = New-Object System.Collections.Generic.List[string]
    $libs.Add($steam)
    $vdf = Join-Path (Join-Path $steam 'steamapps') 'libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        $raw = Get-Content -LiteralPath $vdf -Raw
        foreach ($m in [regex]::Matches($raw, '"path"\s+"([^"]+)"')) { $libs.Add(($m.Groups[1].Value -replace '\\\\', '\')) }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $steamapps = Join-Path $lib 'steamapps'
        $info = Read-AppManifest (Join-Path $steamapps "appmanifest_$AppId.acf")
        if ($null -eq $info) { continue }
        $dir = Join-Path (Join-Path $steamapps 'common') $info.InstallDir
        return @{ Dir = $dir; Build = $info.Build; SteamDir = $steam }
    }
    return $null
}

# Stops if the game is running from $GameDir (or from an unknown path, to be safe).
function Assert-GameClosed([string]$GameDir) {
    $prefix = (Normalize-Dir $GameDir) + '\'
    foreach ($p in @(Get-Process -Name 'MonsterHunterWilds' -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $p.Path } catch { $path = $null }
        if (-not $path -or $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            Stop-Kit 'Monster Hunter Wilds is running. Please close the game completely and run this again.'
        }
    }
}

function Get-KitDataDir([string]$GameDir) {
    return Join-Path (Join-Path (Join-Path $GameDir 'reframework') 'data') 'seamless_coop'
}

function Get-Stamp { return (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') }

# .NET-only helpers: Get-FileHash / Compress-Archive come from script modules that may fail to load when a
# PowerShell 7 module path leaks into Windows PowerShell.
function Get-Sha256([string]$Path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try { return ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '') }
    finally { $fs.Dispose(); $sha.Dispose() }
}

function New-ZipFromDir([string]$SourceDir, [string]$ZipPath) {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    $root = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\') + '\'
    # Entry names use '/' (Windows PowerShell 5.1's ZipFile.CreateFromDirectory may write '\').
    $archive = [System.IO.Compression.ZipFile]::Open($ZipPath, 'Create')
    try {
        foreach ($f in Get-ChildItem -LiteralPath $SourceDir -Recurse -File) {
            $entry = $f.FullName.Substring($root.Length).Replace('\', '/')
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $entry,
                [System.IO.Compression.CompressionLevel]::Optimal)
        }
    } finally {
        $archive.Dispose()
    }
}

# Copies every file under $SourceDir into $DestDir, keeping relative paths. Returns the number of files.
function Copy-Tree([string]$SourceDir, [string]$DestDir) {
    $root = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\') + '\'
    $n = 0
    foreach ($f in Get-ChildItem -LiteralPath $SourceDir -Recurse -File) {
        $dst = Join-Path $DestDir $f.FullName.Substring($root.Length)
        New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
        $n++
    }
    return $n
}

function Test-WriteAccess([string]$Dir) {
    try {
        $probe = Join-Path $Dir ('.seamless-write-test-' + [guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($probe, 'ok')
        Remove-Item -LiteralPath $probe -Force
        return $true
    } catch {
        return $false
    }
}

# Relaunches the current script elevated when the game folder is not writable (rare: most Steam folders are).
# $Bound = the caller's $PSBoundParameters, so every option survives the relaunch.
function Ensure-WriteAccess([string]$Dir, [string]$ScriptPath, $Bound) {
    if (Test-WriteAccess $Dir) { return }
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) { Stop-Kit "Cannot write to $Dir even as administrator." }
    Say 'The game folder needs administrator rights. Windows will ask for permission...' 'Yellow'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$ScriptPath`"")
    foreach ($k in $Bound.Keys) {
        $v = $Bound[$k]
        if ($v -is [System.Management.Automation.SwitchParameter]) { if ($v.IsPresent) { $argList += "-$k" } }
        else { $argList += @("-$k", "`"$v`"") }
    }
    if (-not $Bound.ContainsKey('GameDir')) { $argList += @('-GameDir', "`"$Dir`"") }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    exit 0
}

# Replaces personal details in log text: Windows user/computer name and full Steam IDs (keeps the last 4 digits).
function Protect-LogText([string]$Text) {
    foreach ($name in @($env:USERNAME, $env:COMPUTERNAME)) {
        if ($name -and $name.Length -ge 3) { $Text = [regex]::Replace($Text, [regex]::Escape($name), '<redacted>', 'IgnoreCase') }
    }
    return [regex]::Replace($Text, '7656119\d{6}(\d{4})', '<steamid-...$1>')
}
