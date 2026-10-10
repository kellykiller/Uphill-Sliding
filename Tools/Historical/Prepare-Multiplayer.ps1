#Requires -Version 5.1
# Historical 1.1.0-beta.1 reproduction only; use Prepare-Release.ps1 for current builds.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$EngineRoot,
    [string]$ToolchainRoot = '',
    [switch]$CheckOnly,
    [switch]$Build,
    [switch]$WindowsOnly
)
$ErrorActionPreference = 'Stop'
$sharedScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'Prepare-Release.ps1'
& $sharedScript @PSBoundParameters -Channel HistoricalBeta
