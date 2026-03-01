param(
    [string]$PythonExe = ".\.venv\Scripts\python.exe"
)

$ErrorActionPreference = "Stop"
$InstallerExe = Join-Path $PSScriptRoot "dist\RadialDockInstaller.exe"

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at $PythonExe. Create .venv first."
}

# Clear out a stale installer build if it is still running or locked.
if (Test-Path $InstallerExe) {
    & taskkill /IM "RadialDockInstaller.exe" /F /T *> $null
    Start-Sleep -Milliseconds 400
    try {
        Remove-Item -Path $InstallerExe -Force
    }
    catch {
        throw "Could not remove existing installer EXE at $InstallerExe. Close any running RadialDockInstaller.exe and try again."
    }
}

& $PythonExe -m PyInstaller `
    --noconfirm `
    --clean `
    --onefile `
    --windowed `
    --name "RadialDockInstaller" `
    --paths "src" `
    --add-data "ui;ui" `
    --add-data "assets;assets" `
    "src/radialdock/app.py"

if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $InstallerExe)) {
    throw "PyInstaller reported success, but the installer EXE was not found at $InstallerExe."
}

Write-Host "Build complete. Installer EXE: dist/RadialDockInstaller.exe"
