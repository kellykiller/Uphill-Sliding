#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [Parameter(Mandatory = $true)][string]$GameRoot,
    [string]$RequireSmartFoundationsVersion = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$expectedVersion = '1.1.0-beta.1'
$modsRoot = Join-Path $GameRoot 'FactoryGame\Mods'
$smlPath = Join-Path $modsRoot 'SML\SML.uplugin'
if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) { throw "Archiv fehlt: $ArchivePath" }
if (-not (Test-Path -LiteralPath $smlPath -PathType Leaf)) {
    throw 'SML fehlt auf dem Client. Im Mod Manager zuerst ein Testprofil mit SML und den Server-Mods einrichten.'
}
$sml = Get-Content -LiteralPath $smlPath -Raw | ConvertFrom-Json
if ($sml.SemVersion -notmatch '^3\.(\d+)\.' -or [int]$Matches[1] -lt 12) { throw 'SML 3.12.x oder eine kompatible neuere 3.x-Version wird benoetigt.' }
if ($RequireSmartFoundationsVersion) {
    $smartPath = Join-Path $modsRoot 'GameFeatures\SmartFoundations\SmartFoundations.uplugin'
    if (-not (Test-Path -LiteralPath $smartPath -PathType Leaf)) {
        throw "Auf dem Server ist SmartFoundations $RequireSmartFoundationsVersion installiert. Bitte dieselbe Version zuerst im Mod Manager auf dem Client installieren."
    }
    $smart = Get-Content -LiteralPath $smartPath -Raw | ConvertFrom-Json
    if ($smart.SemVersion -ne $RequireSmartFoundationsVersion) { throw "SmartFoundations-Version muss $RequireSmartFoundationsVersion sein; gefunden: $($smart.SemVersion)" }
}
$running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'FactoryGame*' })
if ($running.Count -gt 0) { throw 'Bitte Satisfactory vor der Installation schliessen.' }
foreach ($legacy in @((Join-Path $modsRoot 'UphillSliding'), (Join-Path $modsRoot 'GameFeatures\SlideMomentum'))) {
    if (Test-Path -LiteralPath $legacy) { throw "Zusaetzlicher alter Mod-Ordner gefunden: $legacy" }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
try {
    foreach ($entry in $archive.Entries) {
        $name = $entry.FullName.Replace('\', '/')
        if ($name.StartsWith('/') -or $name.Contains(':') -or @($name.Split('/') | Where-Object { $_ -eq '..' }).Count -gt 0) {
            throw "Ungueltiger Archivpfad: $name"
        }
    }
    $descriptorEntry = $archive.GetEntry('UphillSliding.uplugin')
    if ($null -eq $descriptorEntry) { throw 'Bitte das Windows-Plattformarchiv verwenden, nicht das kombinierte Archiv.' }
    $reader = New-Object IO.StreamReader($descriptorEntry.Open())
    try { $descriptor = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ($descriptor.SemVersion -ne $expectedVersion -or $descriptor.VersionName -ne $expectedVersion -or
        $descriptor.GameFeature -ne $true -or $descriptor.RequiredOnRemote -ne $true) { throw 'Falsche Beta-Version oder Metadaten im Archiv.' }
    foreach ($target in @('FactoryGameEGS', 'FactoryGameSteam')) {
        $manifestEntry = $archive.GetEntry("Binaries/Win64/$target-Win64-Shipping.modules")
        if ($null -eq $manifestEntry) { throw "Client-Manifest fehlt: $target" }
        $reader = New-Object IO.StreamReader($manifestEntry.Open())
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        $module = [string]$manifest.Modules.SlideMomentum
        if ($manifest.BuildId -ne 'SML' -or -not $module.EndsWith('.dll') -or $module.Contains('/') -or $module.Contains('\')) { throw "Ungueltiges Client-Modul: $target" }
        $binaryEntry = $archive.GetEntry("Binaries/Win64/$module")
        if ($null -eq $binaryEntry -or $binaryEntry.Length -eq 0) { throw "Client-DLL fehlt: $module" }
    }
} finally { $archive.Dispose() }
$backupRoot = Join-Path (Split-Path $GameRoot -Parent) ('UphillSliding-Client-Backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backupRoot | Out-Null
$stage = Join-Path $backupRoot 'Staging'
[IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $stage)
$targetRoot = Join-Path $modsRoot 'GameFeatures\UphillSliding'
$oldBackup = Join-Path $backupRoot 'PreviousPlugin'
New-Item -ItemType Directory -Path (Split-Path $targetRoot -Parent) -Force | Out-Null
if (Test-Path -LiteralPath $targetRoot) { Move-Item -LiteralPath $targetRoot -Destination $oldBackup }
try { Move-Item -LiteralPath $stage -Destination $targetRoot }
catch {
    if ((Test-Path -LiteralPath $oldBackup) -and -not (Test-Path -LiteralPath $targetRoot)) {
        Move-Item -LiteralPath $oldBackup -Destination $targetRoot
    }
    throw
}
Write-Host "Client-Beta $expectedVersion installiert: $targetRoot"
Write-Host "Sicherung: $backupRoot"
Write-Host 'Satisfactory kann jetzt gestartet werden. Bei einer erneuten Profil-Anwendung kann der Mod Manager das Entwicklungspaket ersetzen.'
