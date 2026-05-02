param(
    [switch]$Force,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForwardArgs
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$PythonExe = Join-Path $Root '.venv\Scripts\python.exe'
if (-not (Test-Path $PythonExe)) {
    Write-Host "No .venv at $PythonExe - using 'python' on PATH." -ForegroundColor Yellow
    $PythonExe = "python"
}

$WatchScript = Join-Path $Root 'scripts\dev_watch.py'
if (-not (Test-Path -LiteralPath $WatchScript)) {
    Write-Error "Missing watcher script: $WatchScript"
}

function Normalize-PathMatch([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }
    return $Text.Replace('/', '\').ToLowerInvariant()
}

$WatchScriptFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $WatchScript).Path)
$WatchKey = Normalize-PathMatch $WatchScriptFull

if (-not $Force) {
    $dup = @()
    foreach ($exeName in @('python.exe', 'python3.exe', 'py.exe')) {
        $procs = Get-CimInstance Win32_Process -Filter "Name = '$exeName'" -ErrorAction SilentlyContinue
        if ($null -eq $procs) {
            continue
        }
        foreach ($p in @($procs)) {
            $cmd = $p.CommandLine
            if ([string]::IsNullOrEmpty($cmd)) {
                continue
            }
            $norm = Normalize-PathMatch $cmd
            if ($norm.Contains($WatchKey)) {
                $dup += $p
            }
        }
    }
    if ($dup.Count -gt 0) {
        $pids = ($dup | ForEach-Object { $_.ProcessId }) -join ', '
        Write-Host "Dev watcher already running for this checkout (PID: $pids). Not starting another. Use -Force to run a second instance." -ForegroundColor Yellow
        exit 0
    }
}

$forward = @($ForwardArgs)
& $PythonExe $WatchScript @forward
