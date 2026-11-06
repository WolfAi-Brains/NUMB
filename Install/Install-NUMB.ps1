#Requires -Version 5.1
<#
.SYNOPSIS
  Installs NUMB for the current user (no administrator required).
.DESCRIPTION
  Copies NUMB to %LocalAppData%\WolfAi\NUMB and bundles portable AutoHotkey v2.0.31
  (AutoHotkey64.exe beside the script). Optional system-wide AutoHotkey via -InstallAutoHotkeySystem (admin).
.EXAMPLE
  .\Install-NUMB.ps1 -LaunchNow
.EXAMPLE
  .\Install-NUMB.ps1 -InstallAutoHotkeySystem   # IT / admin only
#>
param(
    [string]$Dest = (Join-Path $env:LOCALAPPDATA 'WolfAi\NUMB'),
    [switch]$StartWithWindows,
    [switch]$NoStartWithWindows,
    [switch]$LaunchNow,
    [switch]$SkipAutoHotkey,
    [switch]$InstallAutoHotkeySystem
)

$ErrorActionPreference = 'Stop'

function Test-AutoHotkeyV2System {
    $paths = @(
        (Join-Path ${env:ProgramFiles} 'AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\v2\AutoHotkey64.exe')
    )
    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) { return $true }
    }
    return [bool](Get-Command autohotkey64.exe -ErrorAction SilentlyContinue)
}

function Install-BundledAutoHotkeySystem {
    $setup = Join-Path $PSScriptRoot 'AutoHotkey_2.0.31_setup.exe'
    if (-not (Test-Path -LiteralPath $setup)) {
        throw "Missing bundled installer: $setup"
    }
    Write-Host 'Installing AutoHotkey v2.0.31 for all users (silent, admin)...'
    $p = Start-Process -FilePath $setup -ArgumentList '/S' -Wait -PassThru -Verb RunAs
    if ($p.ExitCode -ne 0) {
        throw "AutoHotkey setup exited with code $($p.ExitCode)"
    }
    if (-not (Test-AutoHotkeyV2System)) {
        throw 'AutoHotkey v2 was not found after setup.'
    }
    Write-Host 'System AutoHotkey v2 installed.'
}

function Install-PortableAutoHotkey {
    param([string]$TargetDir)
    $src = Join-Path $PSScriptRoot 'portable\AutoHotkey64.exe'
    if (-not (Test-Path -LiteralPath $src)) {
        throw "Missing portable runtime: $src`nExtract AutoHotkey64.exe from AutoHotkey_2.0.31.zip into Install\portable\"
    }
    Copy-Item -LiteralPath $src -Destination (Join-Path $TargetDir 'AutoHotkey64.exe') -Force
    Write-Host 'Copied portable AutoHotkey64.exe (v2.0.31)'
}

$srcRoot = Join-Path $PSScriptRoot '..\number-ops'
$files = @('NUMB.ahk', 'numb.ico', 'Start NUMB.bat', 'README.md')

if ($InstallAutoHotkeySystem) {
    if (-not (Test-AutoHotkeyV2System)) {
        Install-BundledAutoHotkeySystem
    } else {
        Write-Host 'System AutoHotkey v2 already installed.'
    }
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
foreach ($f in $files) {
    $from = Join-Path $srcRoot $f
    if (-not (Test-Path -LiteralPath $from)) {
        throw "Missing source file: $from"
    }
    Copy-Item -LiteralPath $from -Destination (Join-Path $Dest $f) -Force
    Write-Host "Copied $f"
}

if (-not $SkipAutoHotkey) {
    Install-PortableAutoHotkey -TargetDir $Dest
} else {
    Write-Host 'Skipped portable AutoHotkey (-SkipAutoHotkey). Start NUMB.bat needs v2 on PATH or beside the script.'
}

$addStartup = -not $NoStartWithWindows
if ($PSBoundParameters.ContainsKey('StartWithWindows')) {
    $addStartup = [bool]$StartWithWindows
}
if ($addStartup) {
    $startup = [Environment]::GetFolderPath('Startup')
    $linkName = Join-Path $startup 'NUMB.bat'
    $bat = Join-Path $Dest 'Start NUMB.bat'
    Copy-Item -LiteralPath $bat -Destination $linkName -Force
    Write-Host "Startup shortcut: $linkName"
}

Write-Host ""
Write-Host "NUMB installed to: $Dest"
Write-Host "Run: $(Join-Path $Dest 'Start NUMB.bat')"

if ($LaunchNow) {
    Start-Process -FilePath (Join-Path $Dest 'Start NUMB.bat')
}
