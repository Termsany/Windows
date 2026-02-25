[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceIso,

    [Parameter(Mandatory = $true)]
    [string]$OutputIso,

    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = "$PSScriptRoot\\..\\build",

    [Parameter(Mandatory = $false)]
    [string]$CatalogPath = "$PSScriptRoot\\..\\programs\\catalog.json",

    [Parameter(Mandatory = $false)]
    [string[]]$Programs,

    [Parameter(Mandatory = $false)]
    [string]$AutoUnattendTemplate = "$PSScriptRoot\\..\\templates\\Autounattend.xml"
)

$ErrorActionPreference = 'Stop'

function Resolve-Tool {
    param([string]$Name)

    $tool = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $tool) {
        throw "Required tool '$Name' was not found in PATH. Install Windows ADK Deployment Tools (for oscdimg.exe)."
    }

    return $tool.Source
}

if (-not (Test-Path $SourceIso)) {
    throw "Source ISO not found: $SourceIso"
}

if (-not (Test-Path $CatalogPath)) {
    throw "Program catalog not found: $CatalogPath"
}

if (-not (Test-Path $AutoUnattendTemplate)) {
    throw "Autounattend template not found: $AutoUnattendTemplate"
}

$catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json
$validProgramKeys = $catalog.PSObject.Properties.Name

if (-not $Programs -or $Programs.Count -eq 0) {
    Write-Host 'No -Programs supplied. Available keys:'
    $validProgramKeys | ForEach-Object { Write-Host " - $_" }
    throw 'Provide one or more values for -Programs.'
}

$invalid = $Programs | Where-Object { $_ -notin $validProgramKeys }
if ($invalid.Count -gt 0) {
    throw "Unknown program keys: $($invalid -join ', ')"
}

$oscdimg = Resolve-Tool -Name 'oscdimg.exe'

$WorkingDirectory = (Resolve-Path (New-Item -Path $WorkingDirectory -ItemType Directory -Force)).Path
$isoExtractPath = Join-Path $WorkingDirectory 'iso-files'

if (Test-Path $isoExtractPath) {
    Remove-Item $isoExtractPath -Recurse -Force
}
New-Item -Path $isoExtractPath -ItemType Directory -Force | Out-Null

Write-Host "Mounting $SourceIso"
$mounted = Mount-DiskImage -ImagePath $SourceIso -PassThru
try {
    $driveLetter = (Get-Volume -DiskImage $mounted).DriveLetter
    if (-not $driveLetter) {
        throw 'Unable to determine mounted ISO drive letter.'
    }

    $mountedRoot = "$driveLetter`:"
    Write-Host "Copying ISO contents from $mountedRoot to $isoExtractPath"
    robocopy "$mountedRoot\\" "$isoExtractPath\\" /E | Out-Null

    if ($LASTEXITCODE -gt 7) {
        throw "robocopy failed with exit code $LASTEXITCODE"
    }
}
finally {
    Dismount-DiskImage -ImagePath $SourceIso | Out-Null
}

$oemScriptsDir = Join-Path $isoExtractPath 'sources\$OEM$\$$\Setup\Scripts'
$oemSetupDir = Join-Path $isoExtractPath 'sources\$OEM$\$1\Setup'

New-Item -Path $oemScriptsDir -ItemType Directory -Force | Out-Null
New-Item -Path $oemSetupDir -ItemType Directory -Force | Out-Null

Copy-Item "$PSScriptRoot\\Install-SelectedPrograms.ps1" (Join-Path $oemSetupDir 'Install-SelectedPrograms.ps1') -Force
Copy-Item $CatalogPath (Join-Path $oemSetupDir 'program-catalog.json') -Force
($Programs | ConvertTo-Json) | Set-Content (Join-Path $oemSetupDir 'selected-programs.json') -Encoding UTF8

@'
@echo off
powershell.exe -ExecutionPolicy Bypass -File C:\Setup\Install-SelectedPrograms.ps1
exit /b 0
'@ | Set-Content (Join-Path $oemScriptsDir 'SetupComplete.cmd') -Encoding ASCII

Copy-Item $AutoUnattendTemplate (Join-Path $isoExtractPath 'Autounattend.xml') -Force

$bootData = '2#p0,e,b"{0}"#pEF,e,b"{1}"' -f (Join-Path $isoExtractPath 'boot\etfsboot.com'), (Join-Path $isoExtractPath 'efi\microsoft\boot\efisys.bin')

Write-Host "Creating customized ISO at $OutputIso"
& $oscdimg -m -o -u2 -udfver102 -bootdata:$bootData $isoExtractPath $OutputIso
if ($LASTEXITCODE -ne 0) {
    throw "oscdimg failed with exit code $LASTEXITCODE"
}

Write-Host 'Done.'
