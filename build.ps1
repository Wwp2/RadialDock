param(
    [string]$PythonExe = ".\.venv\Scripts\python.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at $PythonExe. Create .venv first."
}

& $PythonExe -m PyInstaller `
    --noconfirm `
    --clean `
    --onefile `
    --windowed `
    --name "RadialDock" `
    --paths "src" `
    --add-data "ui;ui" `
    --add-data "assets;assets" `
    "src/radialdock/app.py"

Write-Host "Build complete. EXE: dist/RadialDock.exe"
