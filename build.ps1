param(
    [string]$PythonExe = ".\.venv\Scripts\python.exe"
)

$ErrorActionPreference = "Stop"
$VersionFile = Join-Path $PSScriptRoot "VERSION.txt"

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at $PythonExe. Create .venv first."
}

if (-not (Test-Path $VersionFile)) {
    Set-Content -Path $VersionFile -Value "0.0.0" -NoNewline
}

$DefaultVersion = (Get-Content -Path $VersionFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($DefaultVersion)) {
    $DefaultVersion = "0.0.0"
}

Write-Host "Enter build version (press Enter to keep $DefaultVersion):" -NoNewline
$VersionInput = Read-Host
if ([string]::IsNullOrWhiteSpace($VersionInput)) {
    $Version = $DefaultVersion
} else {
    $Version = $VersionInput.Trim()
}

if ($Version -notmatch '^[0-9A-Za-z][0-9A-Za-z._-]*$') {
    throw "Invalid version '$Version'. Use only letters, numbers, dots, dashes, and underscores."
}

Set-Content -Path $VersionFile -Value $Version -NoNewline

$InstallerBaseName = "RadialDockInstaller-$Version"
$InstallerExe = Join-Path $PSScriptRoot ("dist\" + $InstallerBaseName + ".exe")

# Clear out a stale installer build if it is still running or locked.
if (Test-Path $InstallerExe) {
    Get-Process -Name $InstallerBaseName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 400
    try {
        Remove-Item -Path $InstallerExe -Force
    }
    catch {
        throw "Could not remove existing installer EXE at $InstallerExe. Close any running $InstallerBaseName.exe and try again."
    }
}

& $PythonExe -m PyInstaller `
    --noconfirm `
    --clean `
    --onefile `
    --windowed `
    --name $InstallerBaseName `
    --paths "src" `
    --add-data "ui;ui" `
    --add-data "assets;assets" `
    --add-data "VERSION.txt;." `
    "src/radialdock/app.py"

if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $InstallerExe)) {
    throw "PyInstaller reported success, but the installer EXE was not found at $InstallerExe."
}

Write-Host "Build complete. Installer EXE: dist/$InstallerBaseName.exe"
