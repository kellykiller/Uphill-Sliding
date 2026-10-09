#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ProjectRoot = 'C:\Users\m.rau\Desktop\Satisfactory-Modding\modding\SM',
    [string]$EngineRoot = 'C:\Program Files\Unreal Engine - CSS',
    [string]$ToolchainRoot = '',
    [switch]$CheckOnly,
    [switch]$Build,
    [switch]$WindowsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$sourceCommit = '4d829ac3ec3a28909f95b23ea50f932c49bafaf0'
$expectedVersion = '1.1.0'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# File hashes and immutable source revision are generated with this script.
$payloadFiles = @(
    [pscustomobject]@{ Path = 'Source/SlideMomentum/Private/SlideMomentum.cpp'; Hash = 'cddcde27bb450108693308beacd13ac6e863b04de1893dea8eef1299163c1402' }
    [pscustomobject]@{ Path = 'Source/SlideMomentum/Public/SlideMomentum.h'; Hash = '56056c21073b2493e54ae1f349cda52a1631b95090e7fe03946c55486d586bf8' }
    [pscustomobject]@{ Path = 'Source/SlideMomentum/SlideMomentum.Build.cs'; Hash = '9d494ccf88c7614fa8f9b91c5a883f9c986fb00213b82f613430f4b939c94f84' }
    [pscustomobject]@{ Path = 'UphillSliding.uplugin'; Hash = 'eab23d1f773348f05401b1dabe8bf9188612e058d8b9856833211b12876ba285' }
    [pscustomobject]@{ Path = 'Config/Alpakit.ini'; Hash = 'b43633661d4b613628ba141765e10d78cb23d34e94ca2e293c06596b4bd2b144' }
    [pscustomobject]@{ Path = 'Config/AccessTransformers.ini'; Hash = 'bb4ba010358ca2388ba0d28196da09112d23e2c0fd24ec1ad0f376887cbb892f' }
    [pscustomobject]@{ Path = 'Config/PluginSettings.ini'; Hash = 'ac00d3df55b209139799deff29fe5e56da6ca44477e16bd1c4da16a2841877e1' }
    [pscustomobject]@{ Path = 'README.md'; Hash = 'bace04a4bc32349c4c0046cf831cc7172a56e4fd0c46e67cdd976bdf4728f92b' }
    [pscustomobject]@{ Path = 'CHANGELOG.md'; Hash = '7ebcb2058c8a64b481b23deaf7227f4657bae92630aa1c491fa9d42d4a241142' }
    [pscustomobject]@{ Path = 'MULTIPLAYER.md'; Hash = 'acacdabac2565d07a27c4adcb0f02a0fc542d68f9804da413b1967b97dd44c42' }
    [pscustomobject]@{ Path = 'Tests/CompileGuards.cpp'; Hash = '94e236d2dd3dc81b6b531edaa981b6d1275228fdee46c99526e5c2af5704319b' }
    [pscustomobject]@{ Path = 'Tests/README.md'; Hash = '23b383002615e2c11ae434a1eede84c04741cebf6b3c98af79ba192b5488129e' }
    [pscustomobject]@{ Path = 'Tests/Regression.cpp'; Hash = '309da8a7f249dc6a6a977d09124ec141f4cc54d972247902df3021185a43ea84' }
    [pscustomobject]@{ Path = 'Tests/run-tests.sh'; Hash = '37bca929703511a7cc1930fc49088ed73c7f921aebeb5c34df997ad5b36fd5c9' }
    [pscustomobject]@{ Path = 'Tests/stubs/CoreMinimal.h'; Hash = 'a957089c6a6c74225bf7c9a779c4bcce04affc0514dda2e689e5939febfc566a' }
    [pscustomobject]@{ Path = 'Tests/stubs/Engine/World.h'; Hash = 'f515b1136a1743382242e6acb0fa7054e2d7307c92674f18d831d9bb6bd4b61b' }
    [pscustomobject]@{ Path = 'Tests/stubs/FGCharacterMovementComponent.h'; Hash = '7d44312606ae7257387122abedb6ad64f2b74f318e84b54028351bc374a76bc6' }
    [pscustomobject]@{ Path = 'Tests/stubs/GameFramework/Character.h'; Hash = '13233eb1082b83e8d30276c0325cd93c2a94a1aaf0d4591b2726b05a50012831' }
    [pscustomobject]@{ Path = 'Tests/stubs/HAL/IConsoleManager.h'; Hash = '7713311f75ae21222ee990df1aee663e260b32cd778ed8de0fb204b3c0193583' }
    [pscustomobject]@{ Path = 'Tests/stubs/Modules/ModuleManager.h'; Hash = '03e7a8c28cca430e6622769ee4cb9fe78a43c70ed0d60357a3d30383294234a7' }
    [pscustomobject]@{ Path = 'Tests/stubs/Patching/NativeHookManager.h'; Hash = '124f215aa21e6435d2ce6515a0cd2bf8f2b31867ff7616b84d9ed3deb34f2e09' }
    [pscustomobject]@{ Path = 'Tests/stubs/Templates/UnrealTemplate.h'; Hash = '7713311f75ae21222ee990df1aee663e260b32cd778ed8de0fb204b3c0193583' }
)

function Read-ZipJson($Entry) {
    $stream = $Entry.Open()
    $reader = New-Object System.IO.StreamReader($stream)
    try { return ($reader.ReadToEnd() | ConvertFrom-Json) }
    finally { $reader.Dispose() }
}

function Test-MergedArchive([string]$Path, [string[]]$Platforms) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($platform in $Platforms) {
            $descriptorEntry = $archive.GetEntry("$platform/UphillSliding.uplugin")
            if ($null -eq $descriptorEntry) { throw "Archiv unvollstaendig: $platform/UphillSliding.uplugin fehlt." }
            $descriptor = Read-ZipJson $descriptorEntry
            if ($descriptor.SemVersion -ne $expectedVersion -or
                $descriptor.VersionName -ne $expectedVersion -or
                $descriptor.RequiredOnRemote -ne $true -or
                $descriptor.IsBetaVersion -ne $false -or
                $descriptor.IsExperimentalVersion -ne $false -or
                $descriptor.GameFeature -ne $true) {
                throw "Falsche Release-Metadaten im Archiv fuer $platform."
            }
            $manifests = @($archive.Entries | Where-Object {
                $_.FullName.StartsWith("$platform/Binaries/", [StringComparison]::Ordinal) -and
                $_.FullName.EndsWith('.modules', [StringComparison]::Ordinal)
            })
            $requiredTargets = @('FactoryServer')
            if ($platform -eq 'Windows') { $requiredTargets = @('FactoryGameEGS', 'FactoryGameSteam') }
            foreach ($target in $requiredTargets) {
                $targetManifests = @($manifests | Where-Object { $_.Name.StartsWith($target + '-', [StringComparison]::Ordinal) })
                if ($targetManifests.Count -eq 0) { throw "Modul-Manifest fuer $platform/$target fehlt." }
                foreach ($manifestEntry in $targetManifests) {
                    $manifest = Read-ZipJson $manifestEntry
                    if ($manifest.BuildId -ne 'SML') { throw "BuildId ist nicht SML: $($manifestEntry.FullName)" }
                    $moduleProperty = $manifest.Modules.PSObject.Properties['SlideMomentum']
                    if ($null -eq $moduleProperty) { throw "SlideMomentum fehlt in $($manifestEntry.FullName)" }
                    $moduleFile = [string]$moduleProperty.Value
                    $extension = '.dll'
                    if ($platform -eq 'LinuxServer') { $extension = '.so' }
                    if (-not $moduleFile.EndsWith($extension, [StringComparison]::OrdinalIgnoreCase)) {
                        throw "Unerwartetes Modulformat fuer $platform : $moduleFile"
                    }
                    $directory = $manifestEntry.FullName.Substring(0, $manifestEntry.FullName.LastIndexOf('/') + 1)
                    $binaryEntry = $archive.GetEntry($directory + $moduleFile)
                    if ($null -eq $binaryEntry -or $binaryEntry.Length -eq 0) {
                        throw "Native Mod-Datei fehlt: $directory$moduleFile"
                    }
                }
            }
            foreach ($extension in @('.pak', '.utoc', '.ucas')) {
                $content = @($archive.Entries | Where-Object {
                    $_.FullName.StartsWith("$platform/Content/", [StringComparison]::Ordinal) -and
                    $_.FullName.EndsWith($extension, [StringComparison]::OrdinalIgnoreCase) -and $_.Length -gt 0
                })
                if ($content.Count -eq 0) { throw "Gekochter Content fehlt fuer $platform : $extension" }
            }
            Write-Host "Archiv geprueft: $platform"
        }
    } finally { $archive.Dispose() }
}

$projectPath = Join-Path $ProjectRoot 'FactoryGame.uproject'
$pluginRoot = Join-Path $ProjectRoot 'Mods\GameFeatures\UphillSliding'
$descriptorPath = Join-Path $pluginRoot 'UphillSliding.uplugin'
$runUat = Join-Path $EngineRoot 'Engine\Build\BatchFiles\RunUAT.bat'
$engineVersionPath = Join-Path $EngineRoot 'Engine\Build\Build.version'
foreach ($path in @($projectPath, $descriptorPath, $engineVersionPath,
    (Join-Path $pluginRoot 'Content\UphillSliding.uasset'),
    (Join-Path $pluginRoot 'Source\SlideMomentum\SlideMomentum.Build.cs'),
    (Join-Path $ProjectRoot 'Source\FactoryGame\Public\FGCharacterMovementComponent.h'),
    (Join-Path $ProjectRoot 'Mods\SML\Source\SML\Public\Patching\NativeHookManager.h'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Benoetigte Datei fehlt: $path" }
}
$engineVersion = Get-Content -LiteralPath $engineVersionPath -Raw | ConvertFrom-Json
if ($engineVersion.MajorVersion -ne 5 -or $engineVersion.MinorVersion -ne 6 -or $engineVersion.PatchVersion -ne 1) {
    throw 'Dieses Update wurde fuer Unreal Engine 5.6.1-CSS vorbereitet.'
}
$currentDescriptor = Get-Content -LiteralPath $descriptorPath -Raw | ConvertFrom-Json
if (@($currentDescriptor.Modules).Count -ne 1 -or $currentDescriptor.Modules[0].Name -ne 'SlideMomentum') {
    throw 'Unerwartete Modulstruktur. Der bestehende Plugin-Ordner wurde nicht geaendert.'
}

if ($Build -or $CheckOnly) {
    foreach ($path in @($runUat, (Join-Path $ProjectRoot 'Mods\Alpakit\Source\Alpakit.Automation\PackagePlugin.cs'))) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Build-Werkzeug fehlt: $path" }
    }
    if (-not $WindowsOnly) {
        $candidates = @($ToolchainRoot)
        foreach ($scope in @('Process', 'User', 'Machine')) {
            $candidates += [Environment]::GetEnvironmentVariable('LINUX_MULTIARCH_ROOT', $scope)
        }
        $candidates += 'C:\UnrealToolchains\v25_clang-18.1.0-rockylinux8'
        $candidates += 'C:\Program Files\UnrealToolchains\v25_clang-18.1.0-rockylinux8'
        $selectedToolchain = $null
        foreach ($candidate in $candidates) {
            if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
            $candidate = $candidate.TrimEnd('\', '/')
            $clang = Join-Path $candidate 'x86_64-unknown-linux-gnu\bin\clang++.exe'
            if (-not (Test-Path -LiteralPath $clang -PathType Leaf)) { continue }
            $versionText = (& $clang '--version' | Out-String)
            if ($LASTEXITCODE -eq 0 -and $versionText -match 'clang version 18\.1\.0') {
                $selectedToolchain = $candidate
                break
            }
        }
        if ($null -eq $selectedToolchain) {
            throw 'Linux-Toolchain fehlt. Auf Windows v25 clang-18.1.0 installieren, PowerShell neu oeffnen und erneut starten. Download: https://dev.epicgames.com/documentation/en-us/unreal-engine/linux-development-requirements-for-unreal-engine?application_version=5.6'
        }
        # UBT performs the final SDK version/sysroot validation (v23 also used clang 18).
        $env:LINUX_MULTIARCH_ROOT = $selectedToolchain + '\'
        Write-Host "Linux-Toolchain: $selectedToolchain (UBT prueft die SDK-Version beim Build)"
    }
}

if (-not $CheckOnly) {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'UnrealEditor*' -or $_.ProcessName -like 'FactoryGame*' -or $_.ProcessName -like 'FactoryServer*'
    })
    if ($running.Count -gt 0) { throw 'Bitte Unreal Editor, Satisfactory und lokale Satisfactory-Server vor dem Update schliessen.' }
}

# Download and check every source file before replacing any existing file.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$stageRoot = Join-Path ([IO.Path]::GetTempPath()) ('UphillSliding-Release-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stageRoot | Out-Null
foreach ($entry in $payloadFiles) {
    $stagePath = Join-Path $stageRoot $entry.Path
    $parent = Split-Path $stagePath -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $url = "https://raw.githubusercontent.com/kellykiller/Uphill-Sliding/$sourceCommit/$($entry.Path)"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $stagePath
    $hash = (Get-FileHash -LiteralPath $stagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $entry.Hash) { throw "Dateipruefung fehlgeschlagen: $($entry.Path). Projektdateien wurden noch nicht geaendert." }
}
Write-Host "Quellstand geprueft: $sourceCommit / $expectedVersion"
if ($CheckOnly) {
    Write-Host 'Pruefung abgeschlossen. Keine Projektdateien geaendert und kein Build gestartet.'
    return
}

$backupRoot = Join-Path (Split-Path $ProjectRoot -Parent) ('UphillSliding-Release-Backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backupRoot | Out-Null
foreach ($entry in $payloadFiles) {
    $existing = Join-Path $pluginRoot $entry.Path
    if (Test-Path -LiteralPath $existing -PathType Leaf) {
        $backupPath = Join-Path (Join-Path $backupRoot 'Plugin') $entry.Path
        New-Item -ItemType Directory -Path (Split-Path $backupPath -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $existing -Destination $backupPath
    }
}
Write-Host "Sicherung der ersetzten Dateien: $backupRoot"
foreach ($entry in $payloadFiles) {
    $destination = Join-Path $pluginRoot $entry.Path
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $stageRoot $entry.Path) -Destination $destination -Force
}
Write-Host "Release-Quellcode $expectedVersion eingesetzt."
if (-not $Build) {
    Write-Host 'Kein Build angefordert. Mit -Build alle drei Plattformen erstellen.'
    return
}

$archiveRoot = Join-Path $ProjectRoot 'Saved\ArchivedPlugins\UphillSliding'
if (Test-Path -LiteralPath $archiveRoot -PathType Container) {
    Move-Item -LiteralPath $archiveRoot -Destination (Join-Path $backupRoot 'ArchivedPlugins')
}
$logPath = Join-Path $backupRoot 'Build-Release.log'
$serverPlatforms = 'Win64+Linux'
$platforms = @('Windows', 'WindowsServer', 'LinuxServer')
if ($WindowsOnly) {
    $serverPlatforms = 'Win64'
    $platforms = @('Windows', 'WindowsServer')
    Write-Warning 'WindowsOnly: Dieses Paket enthaelt keinen Linux-Server-Build.'
}
$uatArgs = @(
    "-ScriptsForProject=$projectPath", 'PackagePlugin', "-project=$projectPath",
    '-clientconfig=Shipping', '-serverconfig=Shipping', '-utf8output',
    '-DLCName=UphillSliding', '-build', '-platform=Win64', '-server',
    "-serverplatform=$serverPlatforms", '-nocompileeditor', '-installed', '-merge'
)
Write-Host ('Build startet: ' + ($platforms -join ', '))
Write-Host "Build-Protokoll: $logPath"
# Launch through a fresh Windows PowerShell process: native stderr is logged as
# text rather than becoming a terminating NativeCommandError in PowerShell ISE.
$runnerArgsPath = Join-Path $stageRoot 'Build-Arguments.clixml'
@{ RunUat = $runUat; UatArgs = $uatArgs } | Export-Clixml -LiteralPath $runnerArgsPath
$launcher = Join-Path $stageRoot 'Launch-Build.ps1'
$launcherText = @'
param([string]$ArgumentsFile)
$ErrorActionPreference = 'Continue'
$arguments = Import-Clixml -LiteralPath $ArgumentsFile
$runUat = $arguments.RunUat
$uatArgs = $arguments.UatArgs
& $runUat @uatArgs 2>&1 | ForEach-Object { $_.ToString() }
exit $LASTEXITCODE
'@
[IO.File]::WriteAllText($launcher, $launcherText, $utf8)
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher $runnerArgsPath | Tee-Object -FilePath $logPath
$buildExitCode = $LASTEXITCODE
if ($buildExitCode -ne 0) {
    throw "Build fehlgeschlagen (Code $buildExitCode). Quellcode wurde aktualisiert; alte Archive liegen in $backupRoot. Protokoll: $logPath"
}
$mergedArchive = Join-Path $archiveRoot 'UphillSliding.zip'
if (-not (Test-Path -LiteralPath $mergedArchive -PathType Leaf)) { throw "Build meldete Erfolg, aber das Archiv fehlt: $mergedArchive" }
Test-MergedArchive $mergedArchive $platforms
foreach ($platform in $platforms) {
    $platformArchive = Join-Path $archiveRoot ("UphillSliding-$platform.zip")
    if (-not (Test-Path -LiteralPath $platformArchive -PathType Leaf)) { throw "Plattformarchiv fehlt: $platformArchive" }
}
Write-Host 'Build und Archivpruefung fuer Uphill Sliding 1.1.0 erfolgreich. Vor dem Upload den finalen Client einmal im Spiel pruefen.'
Write-Host "Archive: $archiveRoot"
Write-Host ('SHA256: ' + (Get-FileHash -LiteralPath $mergedArchive -Algorithm SHA256).Hash)
Write-Host "Protokoll: $logPath"
