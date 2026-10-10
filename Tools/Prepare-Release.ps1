#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$EngineRoot,
    [string]$ToolchainRoot = '',
    [switch]$CheckOnly,
    [switch]$Build,
    [switch]$WindowsOnly,
    [ValidateSet('Release', 'HistoricalBeta')][string]$Channel = 'Release'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
# RELEASE_PINS_BEGIN: immutable source and exact Git blob hashes.
$sourceCommit = '363e632a2cf8bcfb8f2b469c4cabd7225d4c5257'
$expectedVersion = '1.1.1'
$moduleName = 'UphillSliding'
$payloadFiles = @(
    [pscustomobject]@{ Path = 'BUILDING.md'; Hash = 'b8ab0be23d141fc338fa3d6a14f4b32aa37b52c59b5e8c207362aa4e2a20a543' }
    [pscustomobject]@{ Path = 'CHANGELOG.md'; Hash = '55a52058c3bda9f66fae0f4806bf5be3f4a17fe2bd518b38f60525d9c8a2a745' }
    [pscustomobject]@{ Path = 'Config/AccessTransformers.ini'; Hash = 'ad4cfbce58cca963d7387644c09b81ebc9b123ce20ec602683a512c37c67b67d' }
    [pscustomobject]@{ Path = 'Config/Alpakit.ini'; Hash = 'b43633661d4b613628ba141765e10d78cb23d34e94ca2e293c06596b4bd2b144' }
    [pscustomobject]@{ Path = 'Config/PluginSettings.ini'; Hash = 'ac00d3df55b209139799deff29fe5e56da6ca44477e16bd1c4da16a2841877e1' }
    [pscustomobject]@{ Path = 'Docs/History/1.1.0-release-notes.md'; Hash = '15c2dc9ccf6277bf461328441c8c3fbbe4b79d73c45d40fbabd607c0f4d1b8fe' }
    [pscustomobject]@{ Path = 'Docs/History/1.1.0-validation.md'; Hash = '659d7cca6ee684dcacb42a34454cdc115ad04f10ed4a3ffa53b18995507133d0' }
    [pscustomobject]@{ Path = 'LICENSE'; Hash = '77ab5fc59deb9a9b6f1a3161c02ba44ab8ed51e4e04e25462171225042f0d2d6' }
    [pscustomobject]@{ Path = 'MULTIPLAYER.md'; Hash = '6b62a9f72c5b228662508100fbbea9316d71b125a4d473127ae4f046e3b36c2c' }
    [pscustomobject]@{ Path = 'README.md'; Hash = '57ffb6cccdb53066e9ab9c0dfff7338616885283611886718cefce155ff644e7' }
    [pscustomobject]@{ Path = 'RELEASE_NOTES.md'; Hash = '5280f42aacae93f4b9989deb89c338bf9950695b7af8b5e70693e712fbb81869' }
    [pscustomobject]@{ Path = 'Source/UphillSliding/Private/UphillSliding.cpp'; Hash = '21af12b6bc67ccdcca4a35c9f6d7456deea69a4a265e1a4956626f64c3868d74' }
    [pscustomobject]@{ Path = 'Source/UphillSliding/Private/UphillSliding.h'; Hash = 'b7608c4f1803785f28bff3be799137b795ad46c7ed990f6a2f15a0520063e11a' }
    [pscustomobject]@{ Path = 'Source/UphillSliding/UphillSliding.Build.cs'; Hash = '940f0d8a7c5660fed7778b321ec749dc761a36be99f91866a6ec8d298f194833' }
    [pscustomobject]@{ Path = 'TESTING.md'; Hash = '98793ae27a39b055e87e1d101fdb9810ba415e419d361591931cdef9da71ea9b' }
    [pscustomobject]@{ Path = 'Tests/CompileGuards.cpp'; Hash = 'b377d65c01a500236b04eb6720fba5bc95ef0fc6ff5398eafa9563ae29980991' }
    [pscustomobject]@{ Path = 'Tests/README.md'; Hash = '3c20a5e66e07f1a9972d9ba7c44b42dcfe3aa0dccb35eeec5f7b419f37af9b98' }
    [pscustomobject]@{ Path = 'Tests/Regression.cpp'; Hash = '12cac5a93e00908fa9cef6f1df7b790bd93eaf8ff3368e1a6ad75def70a4080d' }
    [pscustomobject]@{ Path = 'Tests/TestSupport.h'; Hash = '85cec0f985fd117f1e00b12c93fa9cb715253ea4e05e42f1ad10ba4079a9970e' }
    [pscustomobject]@{ Path = 'Tests/check-metadata.py'; Hash = 'b5dc5680d3b33f28ddf383a7e780253a6437cec1b8d3bab620e968c105089c49' }
    [pscustomobject]@{ Path = 'Tests/run-tests.sh'; Hash = '5873886b2cd79350caef953b409e948be80f62381db1b969cc282f231a61473b' }
    [pscustomobject]@{ Path = 'Tests/stubs/CoreMinimal.h'; Hash = '866dd14b19d9d95b97d10ad2d59b9d1a8de3140374e87fee2b3f1515ae59ecd5' }
    [pscustomobject]@{ Path = 'Tests/stubs/Engine/World.h'; Hash = 'd8d8bbef3fbf594d2214509fcc1068645c2e5b272f86607f0bed118f0819e557' }
    [pscustomobject]@{ Path = 'Tests/stubs/FGCharacterMovementComponent.h'; Hash = 'd7c22460d1035cbf051185a9c7f5832b2242549faf1239e4323a3e694f0d9b55' }
    [pscustomobject]@{ Path = 'Tests/stubs/GameFramework/Character.h'; Hash = '72b9c5e5d3e7eec7ef16c4dfa04dd300142391a68c10b0a31fae82931a5308f5' }
    [pscustomobject]@{ Path = 'Tests/stubs/HAL/IConsoleManager.h'; Hash = '7713311f75ae21222ee990df1aee663e260b32cd778ed8de0fb204b3c0193583' }
    [pscustomobject]@{ Path = 'Tests/stubs/Modules/ModuleManager.h'; Hash = '3eb71c91b80a17d5caf08ef16bdff26cafd85bc5be14c79d921eb22aa2241dcb' }
    [pscustomobject]@{ Path = 'Tests/stubs/Patching/NativeHookManager.h'; Hash = '8b4cf66ce210f3b3354288e226e6a1ef78b3183ed61cd0d34c01625925650572' }
    [pscustomobject]@{ Path = 'Tests/stubs/Templates/UnrealTemplate.h'; Hash = '7713311f75ae21222ee990df1aee663e260b32cd778ed8de0fb204b3c0193583' }
    [pscustomobject]@{ Path = 'UphillSliding.uplugin'; Hash = 'dba8d9dbc25f5920ae642b1aceb22cc4c5dd2a264cdf30f895dc4768c64254a2' }
)
# RELEASE_PINS_END
$legacyModuleName = 'SlideMomentum' # Migration and historical beta only.
$isHistoricalBeta = $Channel -eq 'HistoricalBeta'
if ($isHistoricalBeta) {
    $pinsPath = Join-Path $PSScriptRoot 'Historical\Beta-Pins.json'
    $pins = Get-Content -LiteralPath $pinsPath -Raw | ConvertFrom-Json
    $sourceCommit = $pins.sourceCommit
    $expectedVersion = $pins.version
    $moduleName = $pins.moduleName
    $payloadFiles = @($pins.files)
    Write-Warning 'Historical beta reproduction only. Do not publish this package.'
}
if ($sourceCommit -notmatch '^[0-9a-f]{40}$' -or $payloadFiles.Count -eq 0) {
    throw 'Source pins are not finalized. Use the completed review branch.'
}
$utf8 = New-Object System.Text.UTF8Encoding($false)

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
        if (-not $isHistoricalBeta -and @($archive.Entries | Where-Object {
            $_.FullName -match [regex]::Escape($legacyModuleName)
        }).Count -gt 0) { throw 'Archive contains a legacy native module or file path.' }
        foreach ($platform in $Platforms) {
            $descriptorEntry = $archive.GetEntry("$platform/UphillSliding.uplugin")
            if ($null -eq $descriptorEntry) { throw "Incomplete archive: missing $platform/UphillSliding.uplugin." }
            $descriptor = Read-ZipJson $descriptorEntry
            if ($descriptor.SemVersion -ne $expectedVersion -or
                $descriptor.VersionName -ne $expectedVersion -or
                @($descriptor.Modules).Count -ne 1 -or $descriptor.Modules[0].Name -ne $moduleName -or
                (-not $isHistoricalBeta -and $descriptor.Version -ne [int]($expectedVersion.Split('.')[0])) -or
                $descriptor.RequiredOnRemote -ne $true -or
                (-not $isHistoricalBeta -and $descriptor.IsBetaVersion -ne $false) -or
                (-not $isHistoricalBeta -and $descriptor.IsExperimentalVersion -ne $false) -or
                $descriptor.GameFeature -ne $true) {
                throw "Incorrect package metadata for $platform."
            }
            $manifests = @($archive.Entries | Where-Object {
                $_.FullName.StartsWith("$platform/Binaries/", [StringComparison]::Ordinal) -and
                $_.FullName.EndsWith('.modules', [StringComparison]::Ordinal)
            })
            $requiredTargets = @('FactoryServer')
            if ($platform -eq 'Windows') { $requiredTargets = @('FactoryGameEGS', 'FactoryGameSteam') }
            foreach ($target in $requiredTargets) {
                $targetManifests = @($manifests | Where-Object { $_.Name.StartsWith($target + '-', [StringComparison]::Ordinal) })
                if ($targetManifests.Count -eq 0) { throw "Module manifest missing for $platform/$target." }
                foreach ($manifestEntry in $targetManifests) {
                    $manifest = Read-ZipJson $manifestEntry
                    if ($manifest.BuildId -ne 'SML') { throw "BuildId is not SML: $($manifestEntry.FullName)" }
                    $moduleProperty = $manifest.Modules.PSObject.Properties[$moduleName]
                    if ($null -eq $moduleProperty) { throw "$moduleName missing in $($manifestEntry.FullName)" }
                    $moduleFile = [string]$moduleProperty.Value
                    if ($moduleFile.Contains('/') -or $moduleFile.Contains('\') -or $moduleFile.Contains(':') -or $moduleFile -eq '..') {
                        throw "Invalid module binary filename: $moduleFile"
                    }
                    $extension = '.dll'
                    if ($platform -eq 'LinuxServer') { $extension = '.so' }
                    if (-not $moduleFile.EndsWith($extension, [StringComparison]::OrdinalIgnoreCase)) {
                        throw "Unexpected module format for $platform : $moduleFile"
                    }
                    $directory = $manifestEntry.FullName.Substring(0, $manifestEntry.FullName.LastIndexOf('/') + 1)
                    $binaryEntry = $archive.GetEntry($directory + $moduleFile)
                    if ($null -eq $binaryEntry -or $binaryEntry.Length -eq 0) {
                        throw "Native mod binary missing: $directory$moduleFile"
                    }
                }
            }
            foreach ($extension in @('.pak', '.utoc', '.ucas')) {
                $content = @($archive.Entries | Where-Object {
                    $_.FullName.StartsWith("$platform/Content/", [StringComparison]::Ordinal) -and
                    $_.FullName.EndsWith($extension, [StringComparison]::OrdinalIgnoreCase) -and $_.Length -gt 0
                })
                if ($content.Count -eq 0) { throw "Cooked content missing for $platform : $extension" }
            }
            Write-Host "Archive checked: $platform"
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
    (Join-Path $ProjectRoot 'Source\FactoryGame\Public\FGCharacterMovementComponent.h'),
    (Join-Path $ProjectRoot 'Mods\SML\Source\SML\Public\Patching\NativeHookManager.h'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file missing: $path" }
}
$engineVersion = Get-Content -LiteralPath $engineVersionPath -Raw | ConvertFrom-Json
if ($engineVersion.MajorVersion -ne 5 -or $engineVersion.MinorVersion -ne 6 -or $engineVersion.PatchVersion -ne 1) {
    throw 'This update requires Unreal Engine 5.6.1-CSS.'
}
$currentDescriptor = Get-Content -LiteralPath $descriptorPath -Raw | ConvertFrom-Json
if (@($currentDescriptor.Modules).Count -ne 1 -or $currentDescriptor.Modules[0].Name -notin @('UphillSliding', $legacyModuleName)) {
    throw 'Unexpected module structure. Existing plugin files were not changed.'
}

$currentModule = [string]$currentDescriptor.Modules[0].Name
$currentBuildRules = Join-Path $pluginRoot ("Source\$currentModule\$currentModule.Build.cs")
if (-not (Test-Path -LiteralPath $currentBuildRules -PathType Leaf)) {
    throw "Existing module build rules missing: $currentBuildRules"
}

if ($Build -or $CheckOnly) {
    foreach ($path in @($runUat, (Join-Path $ProjectRoot 'Mods\Alpakit\Source\Alpakit.Automation\PackagePlugin.cs'))) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Build tool missing: $path" }
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
            throw 'Linux toolchain missing. Install v25 clang-18.1.0 on Windows and open a new PowerShell session. Download: https://dev.epicgames.com/documentation/en-us/unreal-engine/linux-development-requirements-for-unreal-engine?application_version=5.6'
        }
        # UBT performs the final SDK version/sysroot validation (v23 also used clang 18).
        $env:LINUX_MULTIARCH_ROOT = $selectedToolchain + '\'
        Write-Host "Linux toolchain: $selectedToolchain (UBT validates the SDK version during the build)"
    }
}

if (-not $CheckOnly) {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'UnrealEditor*' -or $_.ProcessName -like 'FactoryGame*' -or $_.ProcessName -like 'FactoryServer*'
    })
    if ($running.Count -gt 0) { throw 'Close Unreal Editor, Satisfactory and local dedicated servers before updating.' }
}

# Download and check every source file before replacing any existing file.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$stageRoot = Join-Path ([IO.Path]::GetTempPath()) ('UphillSliding-Release-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stageRoot | Out-Null
try {
    foreach ($entry in $payloadFiles) {
        $stagePath = Join-Path $stageRoot $entry.Path
        $parent = Split-Path $stagePath -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $url = "https://raw.githubusercontent.com/kellykiller/Uphill-Sliding/$sourceCommit/$($entry.Path)"
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $stagePath
        $hash = (Get-FileHash -LiteralPath $stagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $entry.Hash) { throw "Hash mismatch: $($entry.Path). Project files were not changed." }
    }
    Write-Host "Source revision checked: $sourceCommit / $expectedVersion"
    if ($CheckOnly) {
        Write-Host 'Checks completed. Project files unchanged; no build started.'
        return
    }

    $backupRoot = Join-Path (Split-Path $ProjectRoot -Parent) ('UphillSliding-Release-Backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Path $backupRoot | Out-Null
    $backupPlugin = Join-Path $backupRoot 'Plugin'
    Copy-Item -LiteralPath $pluginRoot -Destination $backupPlugin -Recurse
    Write-Host "Full plugin backup: $backupRoot"
    try {
        # Clear this plugin's old module and cached binaries after validating all downloads.
        # A module rename changes DLL/SO names and cannot reuse the previous native build.
        foreach ($relative in @("Source\$currentModule", "Source\$legacyModuleName", 'Source\UphillSliding', 'Binaries', 'Intermediate')) {
            $cachedPath = Join-Path $pluginRoot $relative
            if (Test-Path -LiteralPath $cachedPath) {
                Remove-Item -LiteralPath $cachedPath -Recurse -Force
            }
        }
        foreach ($entry in $payloadFiles) {
            $destination = Join-Path $pluginRoot $entry.Path
            New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $stageRoot $entry.Path) -Destination $destination -Force
        }
    } catch {
        Remove-Item -LiteralPath $pluginRoot -Recurse -Force
        Copy-Item -LiteralPath $backupPlugin -Destination $pluginRoot -Recurse
        throw
    }
    Write-Host "Source update $expectedVersion applied."
    if (-not $Build) {
        Write-Host 'No build requested. Use -Build to package all three platforms.'
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
        Write-Warning 'WindowsOnly: this package does not contain a Linux server build.'
    }
    $uatArgs = @(
        "-ScriptsForProject=$projectPath", 'PackagePlugin', "-project=$projectPath",
        '-clientconfig=Shipping', '-serverconfig=Shipping', '-utf8output',
        '-DLCName=UphillSliding', '-build', '-platform=Win64', '-server',
        "-serverplatform=$serverPlatforms", '-nocompileeditor', '-installed', '-merge'
    )
    Write-Host ('Building: ' + ($platforms -join ', '))
    Write-Host "Build log: $logPath"
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
        throw "Build failed (exit $buildExitCode). Source was updated; previous archives are in $backupRoot. Log: $logPath"
    }
    $mergedArchive = Join-Path $archiveRoot 'UphillSliding.zip'
    if (-not (Test-Path -LiteralPath $mergedArchive -PathType Leaf)) { throw "Build reported success but the archive is missing: $mergedArchive" }
    Test-MergedArchive $mergedArchive $platforms
    foreach ($platform in $platforms) {
        $platformArchive = Join-Path $archiveRoot ("UphillSliding-$platform.zip")
        if (-not (Test-Path -LiteralPath $platformArchive -PathType Leaf)) { throw "Platform archive missing: $platformArchive" }
    }
    Write-Host 'Build and archive checks passed. Run the singleplayer and dedicated-server acceptance tests before publishing.'
    Write-Host "Archive: $archiveRoot"
    Write-Host ('SHA256: ' + (Get-FileHash -LiteralPath $mergedArchive -Algorithm SHA256).Hash)
    Write-Host "Log: $logPath"

} finally {
    if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
}
