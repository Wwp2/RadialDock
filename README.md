# Radial Dock Launcher (Windows 11)

RadialDock is a PySide6 + Qt Quick launcher overlay that appears around the cursor via a global hotkey.

## MVP Status

- Step 1 complete: repo scaffold, `.venv`, dependencies, hello overlay QML window.
- Step 2 complete: Windows global hotkey (`RegisterHotKey` + `WM_HOTKEY`) toggles overlay centered at cursor.
- Step 3 complete: polished radial ring sample layout with smooth open/close animation.
- Step 4 complete: internal ring drag reorder with animated neighbor shifts and drag-out remove.
- Step 5 complete: external Explorer drag-drop into overlay adds file/folder/shortcut entries.
- Step 6 complete: ring items persist to `%APPDATA%\\RadialDock\\config.json` and reload on startup.
- Step 7 complete: ring items now render file/folder/app icons via Qt/Windows icon provider.
- Steps 8-12: planned/scaffolded, currently implementing Step 8 next.

## Prerequisites

- Windows 11
- Python 3.11+ (validated with Python 3.13)

## Run (VS Code friendly)

1. Create and activate venv (Git Bash):

```bash
py -3 -m venv .venv
source .venv/Scripts/activate
```

2. Install dependencies:

```bash
python -m pip install -r requirements.txt
python -m pip install -e .
```

3. Start app:

```bash
python -m radialdock.app
```

4. Press `Ctrl+Space` to toggle the overlay near your cursor.

PowerShell alternative:

```powershell
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m pip install -e .
python -m radialdock.app
```

## CLI Modes

- `python -m radialdock.app --portable`
- `python -m radialdock.app --install`
- `python -m radialdock.app --uninstall`

Install/uninstall is scaffolded now and will be expanded in Step 11 with full shortcuts and UX.

## Build Single EXE

```powershell
.\build.ps1
```

This runs PyInstaller `--onefile` and outputs under `dist\`.

## Project Layout

- `src/radialdock/app.py` entry point
- `src/radialdock/win_hotkey.py` global hotkey integration
- `src/radialdock/install.py` install/uninstall scaffold
- `src/radialdock/model.py` app settings/model scaffold
- `src/radialdock/cache.py` SQLite thumbnail cache scaffold
- `src/radialdock/shell_open.py` shell open helper
- `ui/` QML UI components
- `docs/JOURNAL.md` implementation journal
