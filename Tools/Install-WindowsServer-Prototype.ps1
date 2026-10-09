#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [Parameter(Mandatory = $true)][string]$GameRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-ServerStopped {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'FactoryServer*' })
    if ($running.Count -gt 0) { throw 'Bitte den Satisfactory Dedicated Server zuerst mit Strg+C beenden.' }
}

function Read-ArchiveJson($Archive, [string]$Name) {
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry) { throw "Archivdatei fehlt: $Name" }
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
                $seen.ContainsKey($name)) { throw "Ungueltiger oder doppelter Archivpfad: $name" }
            $seen[$name] = $true
        }
        $descriptor = Read-ArchiveJson $zip "$Plugin.uplugin"
        if ($descriptor.SemVersion -ne $Version -or $descriptor.VersionName -ne $Version) {
            throw "Falsche Version fuer ${Plugin}: erwartet $Version, gefunden $($descriptor.SemVersion)"
        }
        if ($Plugin -eq 'UphillSliding' -and ($descriptor.GameFeature -ne $true -or $descriptor.RequiredOnRemote -ne $true)) {
            throw 'UphillSliding-Multiplayer-Metadaten fehlen.'
        }
        $manifest = Read-ArchiveJson $zip 'Binaries/Win64/FactoryServer-Win64-Shipping.modules'
        $moduleProperty = $manifest.Modules.PSObject.Properties[$Module]
        if ($null -eq $moduleProperty) { throw "Server-Modul fehlt: $Module" }
        $dll = [string]$moduleProperty.Value
        if ($manifest.BuildId -ne 'SML' -or -not $dll.EndsWith('.dll') -or $dll.Contains('/') -or $dll.Contains('\') -or $dll.Contains(':')) {
            throw "Ungueltiges Server-Modul: $dll"
        }
        $binary = $zip.GetEntry("Binaries/Win64/$dll")
        if ($null -eq $binary -or $binary.Length -lt 64) { throw "Server-DLL fehlt: $dll" }
        $stream = $binary.Open()
        try {
            if ($stream.ReadByte() -ne 77 -or $stream.ReadByte() -ne 90) { throw "Keine Windows-DLL: $dll" }
        } finally { $stream.Dispose() }
        foreach ($extension in @('pak', 'utoc', 'ucas')) {
            $entry = $zip.GetEntry("Content/Paks/WindowsServer/${Plugin}FactoryGame-WindowsServer.$extension")
            if ($null -eq $entry -or $entry.Length -eq 0) { throw "WindowsServer-Paket fehlt: $extension" }
        }
    } finally { $zip.Dispose() }
}

if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) { throw "Archiv fehlt: $ArchivePath" }
if (-not (Test-Path -LiteralPath (Join-Path $GameRoot 'FactoryServer.exe') -PathType Leaf)) {
    throw "FactoryServer.exe fehlt unter: $GameRoot"
}
Assert-ServerStopped
$modsRoot = Join-Path $GameRoot 'FactoryGame\Mods'
$smlRoot = Join-Path $modsRoot 'SML'
$targetRoot = Join-Path $modsRoot 'GameFeatures\UphillSliding'
foreach ($legacy in @((Join-Path $modsRoot 'UphillSliding'), (Join-Path $modsRoot 'GameFeatures\SlideMomentum'))) {
    if (Test-Path -LiteralPath $legacy) { throw "Zusaetzlicher alter Mod-Ordner gefunden: $legacy" }
}
Assert-ServerArchive $ArchivePath 'UphillSliding' 'SlideMomentum' '1.1.0-beta.1'
$needsSml = -not (Test-Path -LiteralPath $smlRoot)
if (-not $needsSml) {
    $sml = Get-Content -LiteralPath (Join-Path $smlRoot 'SML.uplugin') -Raw | ConvertFrom-Json
    if ($sml.SemVersion -ne '3.12.0') { throw "Vorhandenes SML ist $($sml.SemVersion); fuer diesen Test wird 3.12.0 verwendet." }
    $smlManifest = Get-Content -LiteralPath (Join-Path $smlRoot 'Binaries\Win64\FactoryServer-Win64-Shipping.modules') -Raw | ConvertFrom-Json
    $smlDll = [string]$smlManifest.Modules.SML
    if ($smlManifest.BuildId -ne 'SML' -or $smlDll -ne 'FactoryServer-SML-Win64-Shipping.dll' -or
        -not (Test-Path -LiteralPath (Join-Path $smlRoot "Binaries\Win64\$smlDll") -PathType Leaf)) {
        throw 'Vorhandenes SML enthaelt kein passendes WindowsServer-Modul.'
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
    Write-Host 'Lade das offizielle SML 3.12.0 WindowsServer-Paket herunter...'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/satisfactorymodding/SatisfactoryModLoader/releases/download/v3.12.0/SML-WindowsServer.zip' -OutFile $smlArchive
    $hash = (Get-FileHash -LiteralPath $smlArchive -Algorithm SHA256).Hash
    if ($hash -ne '4bd6210077abe5864b76c07cfd27270bf5274962f600ea9b3fc1b847e3eca8c8') { throw 'SML-Pruefsumme stimmt nicht. Installation abgebrochen.' }
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
Write-Host "WindowsServer-Beta 1.1.0-beta.1 installiert: $targetRoot"
Write-Host "SML 3.12.0 vorhanden: $smlRoot"
Write-Host "Sicherung und Installationsdateien: $backupRoot"
Write-Host 'Server kann jetzt gestartet werden. Auf dem Spielclient dieselbe Beta und SML verwenden.'
