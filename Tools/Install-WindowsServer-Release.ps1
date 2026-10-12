#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [Parameter(Mandatory = $true)][string]$GameRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$expectedVersion = '1.1.1'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-ServerStopped {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'FactoryServer*' })
    if ($running.Count -gt 0) { throw 'Stop the Satisfactory dedicated server with Ctrl+C first.' }
}

function Read-ArchiveJson($Archive, [string]$Name) {
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry) { throw "Archive entry missing: $Name" }
    $reader = New-Object IO.StreamReader($entry.Open())
    try { return ($reader.ReadToEnd() | ConvertFrom-Json) } finally { $reader.Dispose() }
}

function Assert-ServerArchive([string]$Path, [string]$Plugin, [string]$Module, [string]$Version) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $seen = @{}
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ($name.StartsWith('/') -or $name.Contains(':') -or
                @($name.Split('/') | Where-Object { $_ -eq '..' -or $_.EndsWith('.') -or $_.EndsWith(' ') }).Count -gt 0 -or
                $seen.ContainsKey($name)) { throw "Invalid or duplicate archive path: $name" }
            $seen[$name] = $true
        }
        $descriptor = Read-ArchiveJson $zip "$Plugin.uplugin"
        if ($descriptor.SemVersion -ne $Version -or $descriptor.VersionName -ne $Version) {
            throw "Incorrect version for ${Plugin}: expected $Version, found $($descriptor.SemVersion)"
        }
        if ($Plugin -eq 'UphillSliding') {
            if ($descriptor.Version -ne [int]($Version.Split('.')[0]) -or
                @($descriptor.Modules).Count -ne 1 -or $descriptor.Modules[0].Name -ne $Module -or
                $descriptor.GameFeature -ne $true -or $descriptor.RequiredOnRemote -ne $true -or
                $descriptor.IsBetaVersion -ne $false -or $descriptor.IsExperimentalVersion -ne $false) {
                throw 'Incorrect UphillSliding release metadata or native module name.'
            }
        }
        $manifest = Read-ArchiveJson $zip 'Binaries/Win64/FactoryServer-Win64-Shipping.modules'
        $moduleProperty = $manifest.Modules.PSObject.Properties[$Module]
        if ($null -eq $moduleProperty) { throw "Server module missing: $Module" }
        $dll = [string]$moduleProperty.Value
        if ($manifest.BuildId -ne 'SML' -or -not $dll.EndsWith('.dll') -or $dll.Contains('/') -or $dll.Contains('\') -or $dll.Contains(':')) {
            throw "Invalid server module: $dll"
        }
        $binary = $zip.GetEntry("Binaries/Win64/$dll")
        if ($null -eq $binary -or $binary.Length -lt 64) { throw "Server DLL missing: $dll" }
        $stream = $binary.Open()
        try {
            if ($stream.ReadByte() -ne 77 -or $stream.ReadByte() -ne 90) { throw "Not a Windows DLL: $dll" }
        } finally { $stream.Dispose() }
        foreach ($extension in @('pak', 'utoc', 'ucas')) {
            $entry = $zip.GetEntry("Content/Paks/WindowsServer/${Plugin}FactoryGame-WindowsServer.$extension")
            if ($null -eq $entry -or $entry.Length -eq 0) { throw "WindowsServer package missing: $extension" }
        }
    } finally { $zip.Dispose() }
}

if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) { throw "Archive missing: $ArchivePath" }
if (-not (Test-Path -LiteralPath (Join-Path $GameRoot 'FactoryServer.exe') -PathType Leaf)) {
    throw "FactoryServer.exe missing under: $GameRoot"
}
Assert-ServerStopped
$modsRoot = Join-Path $GameRoot 'FactoryGame\Mods'
$smlRoot = Join-Path $modsRoot 'SML'
$targetRoot = Join-Path $modsRoot 'GameFeatures\UphillSliding'
# Legacy-directory detection only; the current native module is UphillSliding.
foreach ($legacy in @((Join-Path $modsRoot 'UphillSliding'), (Join-Path $modsRoot 'GameFeatures\SlideMomentum'))) {
    if (Test-Path -LiteralPath $legacy) { throw "Additional legacy mod directory found: $legacy" }
}
Assert-ServerArchive $ArchivePath 'UphillSliding' 'UphillSliding' $expectedVersion
$needsSml = -not (Test-Path -LiteralPath $smlRoot)
if (-not $needsSml) {
    $sml = Get-Content -LiteralPath (Join-Path $smlRoot 'SML.uplugin') -Raw | ConvertFrom-Json
    if ($sml.SemVersion -notmatch '^3\.(\d+)\.' -or [int]$Matches[1] -lt 12) {
        throw "SML 3.12.x or a compatible later 3.x version is required; found $($sml.SemVersion)."
    }
    $smlManifest = Get-Content -LiteralPath (Join-Path $smlRoot 'Binaries\Win64\FactoryServer-Win64-Shipping.modules') -Raw | ConvertFrom-Json
    $smlDll = [string]$smlManifest.Modules.SML
    if ($smlManifest.BuildId -ne 'SML' -or $smlDll -ne 'FactoryServer-SML-Win64-Shipping.dll' -or
        -not (Test-Path -LiteralPath (Join-Path $smlRoot "Binaries\Win64\$smlDll") -PathType Leaf)) {
        throw 'Existing SML has no matching WindowsServer module.'
    }
}
$backupRoot = Join-Path (Split-Path $GameRoot -Parent) ('UphillSliding-WindowsServer-Backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backupRoot | Out-Null
$modStage = Join-Path $backupRoot 'ModStaging'
$smlStage = Join-Path $backupRoot 'SmlStaging'
[IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $modStage)
if ($needsSml) {
    $smlArchive = Join-Path $backupRoot 'SML-WindowsServer.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Host 'Downloading the official SML 3.12.0 WindowsServer package...'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/satisfactorymodding/SatisfactoryModLoader/releases/download/v3.12.0/SML-WindowsServer.zip' -OutFile $smlArchive
    $hash = (Get-FileHash -LiteralPath $smlArchive -Algorithm SHA256).Hash
    if ($hash -ne '4bd6210077abe5864b76c07cfd27270bf5274962f600ea9b3fc1b847e3eca8c8') { throw 'SML hash mismatch. Installation aborted.' }
    Assert-ServerArchive $smlArchive 'SML' 'SML' '3.12.0'
    [IO.Compression.ZipFile]::ExtractToDirectory($smlArchive, $smlStage)
}
Assert-ServerStopped
$oldBackup = Join-Path $backupRoot 'PreviousPlugin'
New-Item -ItemType Directory -Path (Split-Path $targetRoot -Parent) -Force | Out-Null
$smlInstalled = $false
$oldMoved = $false
try {
    if ($needsSml) {
        Move-Item -LiteralPath $smlStage -Destination $smlRoot
        $smlInstalled = $true
    }
    if (Test-Path -LiteralPath $targetRoot) {
        Move-Item -LiteralPath $targetRoot -Destination $oldBackup
        $oldMoved = $true
    }
    Move-Item -LiteralPath $modStage -Destination $targetRoot
} catch {
    if ($oldMoved -and -not (Test-Path -LiteralPath $targetRoot)) { Move-Item -LiteralPath $oldBackup -Destination $targetRoot }
    if ($smlInstalled) { Move-Item -LiteralPath $smlRoot -Destination $smlStage }
    throw
}
Write-Host "WindowsServer release $expectedVersion installed: $targetRoot"
Write-Host "SML WindowsServer module present: $smlRoot"
Write-Host "Backup and installation files: $backupRoot"
Write-Host ('Archive SHA256: ' + (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash)
Write-Host 'Server can now be started. Install the same mod version on every client with compatible SML.'
