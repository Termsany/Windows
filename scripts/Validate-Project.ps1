[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host 'Validating JSON and XML files...'
Get-Content ./programs/catalog.json -Raw | ConvertFrom-Json | Out-Null
[xml](Get-Content ./templates/Autounattend.xml -Raw) | Out-Null

Write-Host 'Validating PowerShell script parse...'
Get-ChildItem ./scripts -Filter *.ps1 | ForEach-Object {
    $null = $errors = $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        throw "Parse error(s) in $($_.Name): $($errors | ForEach-Object { $_.Message } | Sort-Object -Unique -join '; ')"
    }
}

Write-Host 'Validation completed successfully.'
