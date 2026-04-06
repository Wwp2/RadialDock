param()

$ErrorActionPreference = "Stop"
$VenvDir = Join-Path $PSScriptRoot ".venv"
$PythonExe = Join-Path $VenvDir "Scripts\python.exe"
$RequirementsFile = Join-Path $PSScriptRoot "requirements.txt"
$VersionFile = Join-Path $PSScriptRoot "VERSION.txt"
$SourceDir = Join-Path $PSScriptRoot "src"
$UiDir = Join-Path $PSScriptRoot "ui"
$AssetsDir = Join-Path $PSScriptRoot "assets"
$EntryScript = Join-Path $SourceDir "radialdock\app.py"
$BuildRoot = Join-Path $PSScriptRoot "build"
$SpecDir = Join-Path $BuildRoot "spec"
$WorkDir = Join-Path $BuildRoot "pyinstaller"

function Get-BootstrapPythonCommand {
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $pyLauncher) {
        return @($pyLauncher.Source, "-3")
    }

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pythonCmd) {
        return @($pythonCmd.Source)
    }

    throw "Could not find a Python launcher. Install Python 3.11+ and ensure either 'py' or 'python' is on PATH."
}

function Invoke-CheckedPython {
    param(
        [string[]]$CommandParts
    )

    & $CommandParts[0] $CommandParts[1..($CommandParts.Length - 1)]
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $($CommandParts -join ' ')"
    }
}

if (-not (Test-Path $PythonExe)) {
    Write-Host "Creating local virtual environment in .venv..."
    $bootstrap = Get-BootstrapPythonCommand
    Invoke-CheckedPython -CommandParts ($bootstrap + @("-m", "venv", $VenvDir))
}

if (-not (Test-Path $PythonExe)) {
    throw "Python executable was still not found at $PythonExe after creating .venv."
}

if (-not (Test-Path $RequirementsFile)) {
    throw "requirements.txt was not found at $RequirementsFile."
}

if (-not (Test-Path $UiDir)) {
    throw "ui directory was not found at $UiDir."
}

if (-not (Test-Path $AssetsDir)) {
    throw "assets directory was not found at $AssetsDir."
}

if (-not (Test-Path $EntryScript)) {
    throw "Entry script was not found at $EntryScript."
}

Write-Host "Installing build dependencies into .venv..."
Invoke-CheckedPython -CommandParts @($PythonExe, "-m", "pip", "install", "-r", $RequirementsFile)
Invoke-CheckedPython -CommandParts @($PythonExe, "-m", "pip", "install", "-e", $PSScriptRoot)

if (-not (Test-Path $VersionFile)) {
    throw "VERSION.txt was not found at $VersionFile."
}

$Version = (Get-Content -Path $VersionFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "VERSION.txt is empty. Set a version number there before building."
}

if ($Version -notmatch '^[0-9A-Za-z][0-9A-Za-z._-]*$') {
    throw "Invalid version '$Version'. Use only letters, numbers, dots, dashes, and underscores."
}

$InstallerBaseName = "RadialDockInstaller-$Version"
$InstallerExe = Join-Path $PSScriptRoot ("dist\" + $InstallerBaseName + ".exe")
$GeneratedSpec = Join-Path $SpecDir ($InstallerBaseName + ".spec")
$ResolvedSourceDir = (Resolve-Path $SourceDir).Path
$ResolvedUiDir = (Resolve-Path $UiDir).Path
$ResolvedAssetsDir = (Resolve-Path $AssetsDir).Path
$ResolvedVersionFile = (Resolve-Path $VersionFile).Path
$ResolvedEntryScript = (Resolve-Path $EntryScript).Path

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
New-Item -ItemType Directory -Force -Path $SpecDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# Clean up legacy versioned spec files that older build script versions left in repo root.
Get-ChildItem -Path $PSScriptRoot -Filter "RadialDockInstaller-*.spec" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

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
    --specpath $SpecDir `
    --workpath $WorkDir `
    --paths $ResolvedSourceDir `
    --add-data "${ResolvedUiDir};ui" `
    --add-data "${ResolvedAssetsDir};assets" `
    --add-data "${ResolvedVersionFile};." `
    $ResolvedEntryScript

if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $InstallerExe)) {
    throw "PyInstaller reported success, but the installer EXE was not found at $InstallerExe."
}

# The generated .spec is not needed for running the app or for this build flow.
if (Test-Path $GeneratedSpec) {
    Remove-Item -Path $GeneratedSpec -Force -ErrorAction SilentlyContinue
}

Write-Host "Build complete. Installer EXE: dist/$InstallerBaseName.exe"
