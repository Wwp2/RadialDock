#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./build.ps1

version="$(tr -d '\r\n' < VERSION.txt)"
installer="./dist/RadialDockInstaller-${version}.exe"

if [[ ! -f "$installer" ]]; then
    echo "Installer not found: $installer" >&2
    exit 1
fi

"$installer" --uninstall --silent
"$installer" --install --silent
