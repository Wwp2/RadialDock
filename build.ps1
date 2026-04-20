param()

$ErrorActionPreference = "Stop"
$RequiredPythonMajor = 3
$RequiredPythonMinor = 13
$VenvDir = Join-Path $PSScriptRoot ".venv"
$PythonExe = Join-Path $VenvDir "Scripts\python.exe"
$RequirementsFile = Join-Path $PSScriptRoot "requirements.txt"
$LockedRequirementsFile = Join-Path $PSScriptRoot "requirements-lock.txt"
$VersionFile = Join-Path $PSScriptRoot "VERSION.txt"
$SourceDir = Join-Path $PSScriptRoot "src"
$UiDir = Join-Path $PSScriptRoot "ui"
$AssetsDir = Join-Path $PSScriptRoot "assets"
$EntryScript = Join-Path $SourceDir "radialdock\app.py"
$BuildRoot = Join-Path $PSScriptRoot "build"
$SpecDir = Join-Path $BuildRoot "spec"
$WorkDir = Join-Path $BuildRoot "pyinstaller"
$DistDir = Join-Path $PSScriptRoot "dist"
$BuildInfoFile = Join-Path $BuildRoot "build-info.json"

function Invoke-CheckedCommand {
    param(
        [string[]]$CommandParts
    )

    if ($CommandParts.Length -lt 1) {
        throw "No command was provided."
    }

    if ($CommandParts.Length -eq 1) {
        & $CommandParts[0]
    }
    else {
        & $CommandParts[0] $CommandParts[1..($CommandParts.Length - 1)]
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $($CommandParts -join ' ')"
    }
}

function Get-PythonVersionText {
    param(
        [string[]]$CommandParts
    )

    $script = "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"
    if ($CommandParts.Length -eq 1) {
        return (& $CommandParts[0] -c $script).Trim()
    }
    return (& $CommandParts[0] $CommandParts[1..($CommandParts.Length - 1)] -c $script).Trim()
}

function Assert-Python313 {
    param(
        [string[]]$CommandParts,
        [string]$Description
    )

    $version = Get-PythonVersionText -CommandParts $CommandParts
    if ($version -notmatch "^$RequiredPythonMajor\.$RequiredPythonMinor\.") {
        throw "$Description must use Python $RequiredPythonMajor.$RequiredPythonMinor.x for reproducible installer builds. Found Python $version. Install Python $RequiredPythonMajor.$RequiredPythonMinor and recreate .venv."
    }
    return $version
}

function Get-BootstrapPythonCommand {
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $pyLauncher) {
        $candidate = @($pyLauncher.Source, "-$RequiredPythonMajor.$RequiredPythonMinor")
        Assert-Python313 -CommandParts $candidate -Description "Python launcher py -$RequiredPythonMajor.$RequiredPythonMinor" | Out-Null
        return $candidate
    }

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pythonCmd) {
        $candidate = @($pythonCmd.Source)
        Assert-Python313 -CommandParts $candidate -Description "python on PATH" | Out-Null
        return $candidate
    }

    throw "Could not find Python $RequiredPythonMajor.$RequiredPythonMinor. Install Python $RequiredPythonMajor.$RequiredPythonMinor and ensure either 'py' or 'python' is on PATH."
}

if (-not (Test-Path $PythonExe)) {
    Write-Host "Creating local virtual environment in .venv with Python $RequiredPythonMajor.$RequiredPythonMinor..."
    $bootstrap = Get-BootstrapPythonCommand
    Invoke-CheckedCommand -CommandParts ($bootstrap + @("-m", "venv", $VenvDir))
}

if (-not (Test-Path $PythonExe)) {
    throw "Python executable was still not found at $PythonExe after creating .venv."
}

$VenvPythonVersion = Assert-Python313 -CommandParts @($PythonExe) -Description ".venv"
Write-Host "Using .venv Python $VenvPythonVersion"

if (-not (Test-Path $RequirementsFile)) {
    throw "requirements.txt was not found at $RequirementsFile."
}

if (-not (Test-Path $LockedRequirementsFile)) {
    throw "requirements-lock.txt was not found at $LockedRequirementsFile. Installer builds require locked dependencies."
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

Write-Host "Installing locked build dependencies into .venv..."
Invoke-CheckedCommand -CommandParts @($PythonExe, "-m", "pip", "install", "-r", $LockedRequirementsFile)
Invoke-CheckedCommand -CommandParts @($PythonExe, "-m", "pip", "install", "--no-build-isolation", "-e", $PSScriptRoot)

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
$InstallerExe = Join-Path $DistDir ($InstallerBaseName + ".exe")
$GeneratedSpec = Join-Path $SpecDir ($InstallerBaseName + ".spec")
$DistBuildInfoFile = Join-Path $DistDir ("RadialDock-build-info-$Version.json")
$ResolvedSourceDir = (Resolve-Path $SourceDir).Path
$ResolvedUiDir = (Resolve-Path $UiDir).Path
$ResolvedAssetsDir = (Resolve-Path $AssetsDir).Path
$ResolvedVersionFile = (Resolve-Path $VersionFile).Path
$ResolvedEntryScript = (Resolve-Path $EntryScript).Path

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
New-Item -ItemType Directory -Force -Path $SpecDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$PythonVersionFull = (& $PythonExe -c "import sys; print(sys.version.replace(chr(10), ' '))").Trim()
$PySide6Version = (& $PythonExe -c "import PySide6; print(PySide6.__version__)").Trim()
$PyInstallerVersion = (& $PythonExe -c "import PyInstaller; print(PyInstaller.__version__)").Trim()
$PillowVersion = (& $PythonExe -c "import PIL; print(PIL.__version__)").Trim()
$PipFreeze = @(& $PythonExe -m pip freeze)
$SourceCommit = ""
try {
    $SourceCommit = (& git -C $PSScriptRoot rev-parse HEAD 2>$null).Trim()
}
catch {
    $SourceCommit = ""
}

$BuildInfo = [ordered]@{
    app_version = $Version
    build_time = (Get-Date).ToUniversalTime().ToString("o")
    python_executable = $PythonExe
    python_version = $PythonVersionFull
    pyside6_version = $PySide6Version
    pyinstaller_version = $PyInstallerVersion
    pillow_version = $PillowVersion
    os_version = [System.Environment]::OSVersion.VersionString
    source_commit = $SourceCommit
    pip_freeze = $PipFreeze
}
$BuildInfo | ConvertTo-Json -Depth 5 | Set-Content -Path $BuildInfoFile -Encoding UTF8

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
    --add-data "${BuildInfoFile};." `
    $ResolvedEntryScript

if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $InstallerExe)) {
    throw "PyInstaller reported success, but the installer EXE was not found at $InstallerExe."
}

Copy-Item -Path $BuildInfoFile -Destination $DistBuildInfoFile -Force

# The generated .spec is not needed for running the app or for this build flow.
if (Test-Path $GeneratedSpec) {
    Remove-Item -Path $GeneratedSpec -Force -ErrorAction SilentlyContinue
}

Write-Host "Build complete. Installer EXE: dist/$InstallerBaseName.exe"
Write-Host "Build info: dist/$(Split-Path -Leaf $DistBuildInfoFile)"
