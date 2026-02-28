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
- Step 8 complete: clicking folder ring items opens inner tile view, and tile click opens file/folder.
- Step 9 complete: image thumbnails are cached via SQLite + disk cache and shown in folder tiles.
- Step 10 complete: center-click settings menu with persisted runtime preferences and confirmations.
- Step 11 complete: separate automatic icon/folder refresh controls plus manual refresh behavior.
- Steps 12-13: planned/scaffolded, currently implementing Step 12 next.

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

Interaction notes:
- `Right click` works as a universal back action:
  - closes folder sub-view if open
  - otherwise closes the radial overlay
- Click the center core to open the settings panel.
- Settings now include `Restart App` and `Quit App` controls for full process control.
- Folder sub-view adapts size to item count.
- If folder contains more than `50` items, compact list mode is used.
- Settings are persisted per user at `%APPDATA%\\RadialDock\\config.json`.
- Automatic refresh settings let users avoid disk existence scans when disabled.
- `Manual Refresh` runs only the checks whose automatic toggle is currently off.

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

Install/uninstall is scaffolded now and will be expanded in Step 12 with full shortcuts and UX.

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
