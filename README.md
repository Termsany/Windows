# Custom Windows ISO Builder (with selectable auto-install programs)

This project creates a new Windows ISO that installs selected programs automatically after Windows setup.

## What it does

- Mounts an existing Windows ISO.
- Copies ISO files into a working folder.
- Injects setup scripts under `sources/$OEM$`.
- Stores your selected app list (`selected-programs.json`).
- Uses `SetupComplete.cmd` to run a PowerShell installer on first boot.
- Rebuilds a bootable ISO using `oscdimg.exe`.
- Includes a dashboard GUI so you can select programs visually.

## Requirements

Run on a Windows machine with:

- PowerShell 5+.
- Windows ADK Deployment Tools (`oscdimg.exe` in `PATH`).
- Internet during setup (for Chocolatey + package downloads).

## Program catalog

Edit available apps in:

- `programs/catalog.json`

Each key is what you pass to `-Programs` (or select in the GUI).

## Option 1: Build via command line

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Build-CustomWindowsIso.ps1 \
  -SourceIso "C:\ISO\Win11_23H2_English_x64v2.iso" \
  -OutputIso "C:\ISO\Win11_Custom.iso" \
  -Programs git vscode googlechrome 7zip
```

If `-Programs` is omitted, the script prints available keys and exits.

## Option 2: Build via dashboard GUI

Launch:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-IsoBuilderDashboard.ps1
```

In the dashboard:

1. Pick source ISO.
2. Pick output ISO location.
3. (Optional) Pick a working directory.
4. Check desired programs.
5. Click **Build Custom ISO**.

## How program installation runs

During setup, `SetupComplete.cmd` runs:

- `C:\Setup\Install-SelectedPrograms.ps1`

That script:

1. Installs Chocolatey if needed.
2. Reads `C:\Setup\selected-programs.json`.
3. Maps keys using `C:\Setup\program-catalog.json`.
4. Installs each package silently with Chocolatey.

Logs are written to:

- `C:\Setup\install-programs.log`

## Notes

- You can expand `catalog.json` with more Chocolatey packages.
- This is a baseline unattended configuration template; adapt `templates/Autounattend.xml` to your locale, image index, and setup preferences.


## Run validation in Docker

If you want a reproducible environment for checks, use Docker: 

```bash
docker compose run --rm validator
```

This runs `scripts/Validate-Project.ps1` inside a PowerShell container and validates:

- `programs/catalog.json` JSON format
- `templates/Autounattend.xml` XML format
- PowerShell parse correctness for all `scripts/*.ps1` files
