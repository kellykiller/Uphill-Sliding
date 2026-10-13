#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$toolFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File -Recurse | Sort-Object FullName)
$failed = $false
foreach ($toolFile in $toolFiles) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $toolFile.FullName, [ref]$tokens, [ref]$parseErrors
    )
    foreach ($parseError in @($parseErrors)) {
        Write-Host ('FAIL {0}:{1}:{2}: {3}' -f $toolFile.FullName,
            $parseError.Extent.StartLineNumber, $parseError.Extent.StartColumnNumber,
            $parseError.Message)
        $failed = $true
    }
    $bytes = [IO.File]::ReadAllBytes($toolFile.FullName)
    if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) {
        Write-Host ('FAIL non-ASCII PowerShell file: ' + $toolFile.FullName)
        $failed = $true
    }
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    if ($text.Replace("`r`n", '').Contains("`n")) {
        Write-Host ('FAIL PowerShell file must use CRLF: ' + $toolFile.FullName)
        $failed = $true
    }
}
if ($failed) { exit 1 }
Write-Host ('PASS parsed {0} PowerShell files; ASCII/CRLF; PowerShell {1}' -f
    $toolFiles.Count, $PSVersionTable.PSVersion)
