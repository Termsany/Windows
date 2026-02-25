# Windows ISO Builder (Node.js Web Dashboard)

This project now uses **Node.js** for the dashboard and orchestration layer.
You can manage ISO builds through a browser-based UI instead of Windows Forms.

## Features

- Web dashboard to configure build inputs.
- Program selection from `programs/catalog.json`
- Manual program creation directly from the dashboard (saved to catalog).
- Start and monitor build jobs from browser.
- Reuses existing PowerShell ISO build scripts on Windows.
- Docker support for running dashboard and validation.

## Architecture

- `src/server.js`: Node.js HTTP server + API.
- `public/`: frontend dashboard (HTML/CSS/JS).
- `scripts/Build-CustomWindowsIso.ps1`: ISO creation engine.
- `scripts/Install-SelectedPrograms.ps1`: first-boot package installer.

## Requirements

### For running the web dashboard

- Node.js 18+

### For actual ISO build execution

Run on **Windows** with:

- PowerShell 5+
- Windows ADK Deployment Tools (`oscdimg.exe` in `PATH`)
- Internet access during setup (Chocolatey packages)

> The web dashboard can run anywhere, but build execution requires Windows (`powershell.exe`).

## Run locally

```bash
npm start
```

Open:

- `http://localhost:3000`

## Use the dashboard

1. Enter source Windows ISO path.
2. Enter output ISO path.
3. (Optional) Enter working directory.
4. (Optional) Add new programs manually in **Add Program Manually** section.
5. Select programs.
6. Click **Build Custom ISO**.

The dashboard polls build status and streams logs.

## API

- `GET /api/catalog` → program catalog
- `POST /api/catalog` → add a program manually to catalog
- `POST /api/build` → start build job
- `GET /api/build/:id` → job status/logs

## Docker

### Start dashboard

```bash
docker compose up dashboard
```

### Run validation

```bash
docker compose run --rm validator
```

## Validation command

```bash
npm run validate
```

Checks:

- Catalog JSON validity
- Template XML basic structure
- Required Node dashboard files exist
