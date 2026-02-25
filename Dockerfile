FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

WORKDIR /workspace

COPY . /workspace

CMD ["pwsh", "-NoLogo", "-NoProfile", "-Command", "Write-Host 'Container ready. Run: pwsh ./scripts/Validate-Project.ps1'"]
