[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$CatalogPath = "$PSScriptRoot\..\programs\catalog.json",

    [Parameter(Mandatory = $false)]
    [string]$BuilderScriptPath = "$PSScriptRoot\Build-CustomWindowsIso.ps1"
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $CatalogPath)) {
    throw "Catalog not found: $CatalogPath"
}

if (-not (Test-Path $BuilderScriptPath)) {
    throw "Builder script not found: $BuilderScriptPath"
}

$catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json
$programKeys = $catalog.PSObject.Properties.Name | Sort-Object

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows ISO Builder Dashboard'
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = 'CenterScreen'
$form.Topmost = $false

$font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.Font = $font

$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Location = New-Object System.Drawing.Point(20, 20)
$lblSource.Size = New-Object System.Drawing.Size(160, 20)
$lblSource.Text = 'Source Windows ISO:'
$form.Controls.Add($lblSource)

$txtSource = New-Object System.Windows.Forms.TextBox
$txtSource.Location = New-Object System.Drawing.Point(20, 45)
$txtSource.Size = New-Object System.Drawing.Size(720, 25)
$form.Controls.Add($txtSource)

$btnBrowseSource = New-Object System.Windows.Forms.Button
$btnBrowseSource.Location = New-Object System.Drawing.Point(750, 43)
$btnBrowseSource.Size = New-Object System.Drawing.Size(110, 28)
$btnBrowseSource.Text = 'Browse...'
$form.Controls.Add($btnBrowseSource)

$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Location = New-Object System.Drawing.Point(20, 85)
$lblOutput.Size = New-Object System.Drawing.Size(160, 20)
$lblOutput.Text = 'Output ISO path:'
$form.Controls.Add($lblOutput)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(20, 110)
$txtOutput.Size = New-Object System.Drawing.Size(720, 25)
$form.Controls.Add($txtOutput)

$btnBrowseOutput = New-Object System.Windows.Forms.Button
$btnBrowseOutput.Location = New-Object System.Drawing.Point(750, 108)
$btnBrowseOutput.Size = New-Object System.Drawing.Size(110, 28)
$btnBrowseOutput.Text = 'Browse...'
$form.Controls.Add($btnBrowseOutput)

$lblWorkDir = New-Object System.Windows.Forms.Label
$lblWorkDir.Location = New-Object System.Drawing.Point(20, 150)
$lblWorkDir.Size = New-Object System.Drawing.Size(220, 20)
$lblWorkDir.Text = 'Working directory (optional):'
$form.Controls.Add($lblWorkDir)

$txtWorkDir = New-Object System.Windows.Forms.TextBox
$txtWorkDir.Location = New-Object System.Drawing.Point(20, 175)
$txtWorkDir.Size = New-Object System.Drawing.Size(720, 25)
$form.Controls.Add($txtWorkDir)

$btnBrowseWorkDir = New-Object System.Windows.Forms.Button
$btnBrowseWorkDir.Location = New-Object System.Drawing.Point(750, 173)
$btnBrowseWorkDir.Size = New-Object System.Drawing.Size(110, 28)
$btnBrowseWorkDir.Text = 'Browse...'
$form.Controls.Add($btnBrowseWorkDir)

$lblPrograms = New-Object System.Windows.Forms.Label
$lblPrograms.Location = New-Object System.Drawing.Point(20, 215)
$lblPrograms.Size = New-Object System.Drawing.Size(250, 20)
$lblPrograms.Text = 'Select programs to auto-install:'
$form.Controls.Add($lblPrograms)

$programList = New-Object System.Windows.Forms.CheckedListBox
$programList.Location = New-Object System.Drawing.Point(20, 240)
$programList.Size = New-Object System.Drawing.Size(840, 260)
$programList.CheckOnClick = $true
$form.Controls.Add($programList)

foreach ($key in $programKeys) {
    $display = $catalog.$key.displayName
    [void]$programList.Items.Add("$display ($key)")
}

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Location = New-Object System.Drawing.Point(20, 515)
$btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
$btnSelectAll.Text = 'Select All'
$form.Controls.Add($btnSelectAll)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Location = New-Object System.Drawing.Point(150, 515)
$btnClear.Size = New-Object System.Drawing.Size(120, 30)
$btnClear.Text = 'Clear'
$form.Controls.Add($btnClear)

$btnBuild = New-Object System.Windows.Forms.Button
$btnBuild.Location = New-Object System.Drawing.Point(690, 515)
$btnBuild.Size = New-Object System.Drawing.Size(170, 30)
$btnBuild.Text = 'Build Custom ISO'
$form.Controls.Add($btnBuild)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 560)
$txtLog.Size = New-Object System.Drawing.Size(840, 90)
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$form.Controls.Add($txtLog)

function Append-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $txtLog.AppendText("[$timestamp] $Message`r`n")
}

$btnBrowseSource.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'ISO files (*.iso)|*.iso|All files (*.*)|*.*'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtSource.Text = $dlg.FileName
    }
})

$btnBrowseOutput.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = 'ISO files (*.iso)|*.iso|All files (*.*)|*.*'
    $dlg.FileName = 'Windows_Custom.iso'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutput.Text = $dlg.FileName
    }
})

$btnBrowseWorkDir.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtWorkDir.Text = $dlg.SelectedPath
    }
})

$btnSelectAll.Add_Click({
    for ($i = 0; $i -lt $programList.Items.Count; $i++) {
        $programList.SetItemChecked($i, $true)
    }
})

$btnClear.Add_Click({
    for ($i = 0; $i -lt $programList.Items.Count; $i++) {
        $programList.SetItemChecked($i, $false)
    }
})

$btnBuild.Add_Click({
    try {
        $source = $txtSource.Text.Trim()
        $output = $txtOutput.Text.Trim()
        $workDir = $txtWorkDir.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($source)) {
            [System.Windows.Forms.MessageBox]::Show('Please choose a source ISO file.', 'Missing source ISO') | Out-Null
            return
        }

        if ([string]::IsNullOrWhiteSpace($output)) {
            [System.Windows.Forms.MessageBox]::Show('Please choose an output ISO file path.', 'Missing output path') | Out-Null
            return
        }

        if (-not (Test-Path $source)) {
            [System.Windows.Forms.MessageBox]::Show('Source ISO path does not exist.', 'Invalid source path') | Out-Null
            return
        }

        $selectedProgramKeys = @()
        foreach ($checkedItem in $programList.CheckedItems) {
            if ($checkedItem -match '\(([^\)]+)\)$') {
                $selectedProgramKeys += $Matches[1]
            }
        }

        if ($selectedProgramKeys.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Select at least one program.', 'No programs selected') | Out-Null
            return
        }

        Append-Log "Starting build..."
        Append-Log "Selected programs: $($selectedProgramKeys -join ', ')"

        $argList = @('-ExecutionPolicy', 'Bypass', '-File', $BuilderScriptPath, '-SourceIso', $source, '-OutputIso', $output, '-Programs')
        $argList += $selectedProgramKeys

        if (-not [string]::IsNullOrWhiteSpace($workDir)) {
            $argList += @('-WorkingDirectory', $workDir)
        }

        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Append-Log 'Build completed successfully.'
            [System.Windows.Forms.MessageBox]::Show('Custom ISO created successfully.', 'Success') | Out-Null
        }
        else {
            Append-Log "Build failed. Exit code: $($process.ExitCode)"
            [System.Windows.Forms.MessageBox]::Show("Build failed with exit code $($process.ExitCode). Check terminal output.", 'Build failed') | Out-Null
        }
    }
    catch {
        Append-Log "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Error') | Out-Null
    }
})

Append-Log 'Dashboard loaded. Fill paths, select programs, then click Build Custom ISO.'

[void]$form.ShowDialog()
