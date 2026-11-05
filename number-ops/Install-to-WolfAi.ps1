#Requires -Version 5.1
<#
.SYNOPSIS
  Copies NUMB into C:\WolfAi\number-ops on this Windows machine.
#>
$ErrorActionPreference = 'Stop'

$destRoot = 'C:\WolfAi\number-ops'
$src = $PSScriptRoot

New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

$files = @(
    'NUMB.ahk',
    'numb.ico',
    'Start NUMB.bat',
    'README.md',
    'Install-to-WolfAi.ps1'
)

foreach ($f in $files) {
    $from = Join-Path $src $f
    if (-not (Test-Path -LiteralPath $from)) {
        Write-Warning "Skipped (missing): $f"
        continue
    }
    Copy-Item -LiteralPath $from -Destination (Join-Path $destRoot $f) -Force
    Write-Host "Copied $f"
}

$portableAhk = Join-Path $src '..\Install\portable\AutoHotkey64.exe'
if (Test-Path -LiteralPath $portableAhk) {
    Copy-Item -LiteralPath $portableAhk -Destination (Join-Path $destRoot 'AutoHotkey64.exe') -Force
    Write-Host 'Copied AutoHotkey64.exe (portable v2)'
} else {
    Write-Warning 'No Install\portable\AutoHotkey64.exe — run Start NUMB.bat only if AutoHotkey v2 is installed.'
}

Write-Host ""
Write-Host "Dev copy installed to $destRoot"
Write-Host "Run:  $destRoot\Start NUMB.bat"
Write-Host ""
Write-Host "Other PCs (no admin): use  C:\WolfAi\NUMB\Install\Install NUMB.bat"
Write-Host "  or zip Install + number-ops folders (see Install\README.md)."
