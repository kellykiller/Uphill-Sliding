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
# RELEASE_PINS_BEGIN: regenerated after the source changes are committed.
$sourceCommit = 'PENDING_SOURCE_COMMIT'
$expectedVersion = '1.1.1'
$moduleName = 'UphillSliding'
$payloadFiles = @()
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
