#Requires -Version 5.1
<#
.SYNOPSIS
  Builds NUMB-Setup-<version>.exe with Inno Setup 6 (if ISCC is installed).
#>
$ErrorActionPreference = 'Stop'

$iss = Join-Path $PSScriptRoot 'NUMB-Setup.iss'
$verMatch = Select-String -Path $iss -Pattern '#define MyAppVersion "([^"]+)"' | Select-Object -First 1
$appVer = if ($verMatch) { $verMatch.Matches.Groups[1].Value } else { '1.0' }
$isccCandidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe"
)

$iscc = $null
foreach ($c in $isccCandidates) {
    if (Test-Path -LiteralPath $c) {
        $iscc = $c
        break
    }
}

if (-not $iscc) {
    Write-Host 'Inno Setup 6 not found. Install from https://jrsoftware.org/isdl.php'
    Write-Host "Then run:  `"${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe`" `"$iss`""
    Write-Host ''
    Write-Host 'Without Inno, zip these folders for other PCs and run Install\Install NUMB.bat:'
    Write-Host '  C:\WolfAi\NUMB\Install'
    Write-Host '  C:\WolfAi\NUMB\number-ops'
    exit 1
}

& $iscc $iss
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = Join-Path $PSScriptRoot "Output\NUMB-Setup-$appVer.exe"
Write-Host ''
Write-Host "Built: $out"
