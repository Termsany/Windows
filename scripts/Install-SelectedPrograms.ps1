[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProgramListPath = 'C:\Setup\selected-programs.json',

    [Parameter(Mandatory = $false)]
    [string]$CatalogPath = 'C:\Setup\program-catalog.json',

    [Parameter(Mandatory = $false)]
    [string]$LogPath = 'C:\Setup\install-programs.log'
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    $line | Tee-Object -FilePath $LogPath -Append
}

function Ensure-Chocolatey {
    if (Get-Command choco.exe -ErrorAction SilentlyContinue) {
        Write-Log 'Chocolatey is already installed.'
        return
    }

    Write-Log 'Installing Chocolatey...'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

if (-not (Test-Path $ProgramListPath)) {
    Write-Log "No selected-programs file found at $ProgramListPath. Nothing to install."
    exit 0
}

if (-not (Test-Path $CatalogPath)) {
    throw "Catalog not found: $CatalogPath"
}

$selectedPrograms = Get-Content $ProgramListPath -Raw | ConvertFrom-Json
$catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json

if ($selectedPrograms.Count -eq 0) {
    Write-Log 'Selected program list is empty. Nothing to install.'
    exit 0
}

Ensure-Chocolatey

foreach ($programKey in $selectedPrograms) {
    if (-not $catalog.PSObject.Properties.Name.Contains($programKey)) {
        Write-Log "Skipping unknown program key: $programKey"
        continue
    }

    $definition = $catalog.$programKey
    if ($definition.source -ne 'choco') {
        Write-Log "Skipping unsupported source '$($definition.source)' for key: $programKey"
        continue
    }

    $packageName = $definition.package
    Write-Log "Installing '$($definition.displayName)' via Chocolatey package '$packageName'..."

    choco install $packageName -y --no-progress | Tee-Object -FilePath $LogPath -Append

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Installation command returned exit code $LASTEXITCODE for package '$packageName'."
    }
}

Write-Log 'Program installation script finished.'
