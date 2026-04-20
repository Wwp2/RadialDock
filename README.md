# Radial Dock Launcher (Windows 11)

RadialDock is a Windows launcher overlay built with PySide6 and Qt Quick. It opens as a radial menu, lets you pin files, folders, apps, and shortcuts, and is designed for fast mouse-first launching.

https://github.com/user-attachments/assets/e17b115a-a539-4d00-aa30-3c99df3c2667

## What It Does

- Opens the dock with a global hotkey near the cursor
- Lets you drag files, folders, and shortcuts in from Explorer
- Supports folders, groups, thumbnail previews, and shortcut-aware icons
- Includes a settings panel for shortcut capture, refresh behavior, startup behavior, backups, and more

## Prerequisites

- Windows 11
- Python 3.11+ (validated with Python 3.13)

## Build Installer

Use this when you want the packaged installer EXE and a gui installer (the installer also has easy 'autorun on startup' setup):

```powershell
.\build.ps1
```

The build:

- creates or reuses the local `.venv`
- installs the required build/runtime packages into that `.venv`
- reads the version from `VERSION.txt`
- creates `dist\RadialDockInstaller-<version>.exe`

This keeps the build dependencies out of the user's global Python installation.

When installed, the runtime app is copied to:

- `%LocalAppData%\RadialDock\RadialDock.exe`

That installed `RadialDock.exe` is the normal day-to-day launcher binary.

## Rebuild And Reinstall Script

For development, this is the preferred workflow over running uninstall/install commands manually:

```bash
./rebuild_reinstall.sh
```

This script:

- runs `build.ps1`
- reads the current version from `VERSION.txt`
- runs the matching installer with `--uninstall --silent`
- runs the same installer again with `--install --silent`

## How To Use The App

1. Launch the app.
2. Press `Ctrl+Space` to open the dock.
3. Drag files, folders, or shortcuts from Explorer into the ring to pin them.
4. Click the center core to open Settings.
5. Hold the center core for 2 seconds to toggle `Group Edit Mode`.

Main interaction rules:

- `Right click` is the universal back action
- Clicking a group opens a smaller radial group menu
- Dragging an item out of an open group moves it back to the main ring
- Fresh installs start with an empty ring

## Run The App From Source

1. Create and activate venv in Git Bash:

```bash
python -m venv .venv
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

Basic source-run notes:

- `Right click` is the universal back action
- Click the center core to open Settings
- Hold the center core for 2 seconds to toggle `Group Edit Mode`
- Fresh installs start with an empty ring
- The more detailed behavior list is in `Feature Summary` below

PowerShell alternative:

```powershell
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m pip install -e .
python -m radialdock.app
```

## Feature Summary

- `Right click` works as a universal back action:
  - closes the group rename prompt if open
  - closes an open icon group if open
  - closes folder sub-view if open
  - otherwise closes the radial overlay
- Click the center core to open the settings panel.
- Hold the center core for 2 seconds to toggle `Group Edit Mode`.
- In `Group Edit Mode`, drag one ring item onto another to merge them into a named group.
- In normal mode, clicking a group opens a smaller radial sub-ring on top of the main dock.
- In normal mode, you can drag an item out of an open group sub-ring and drop it onto the main dock to move it back to the top level.
- Settings include, but is not limited to:
  - `Restart App` and `Quit App`
  - single-file backup export/import
  - `Automatic Item Alignement`
  - `Show file extensions`
  - `Close after launch`
  - capture-based shortcut picking
  - `Launch on startup`
- Image files use cached thumbnail previews as full-bleed visuals in the main ring and tile-mode folder view.
- Windows `.lnk` and `.url` shortcuts use Windows shell-aware icon extraction.
- Non-image icons now return a cheap placeholder first and resolve the real Windows icon in the background, so first folder open is less likely to stall on cold boot.
- Missing image previews load in the background so folder/menu open stays responsive while thumbnails fill in.
- Folder views open first and load refreshed contents after, while cached-only mode still opens immediately with no new scan.
- Folder views now open immediately from cached entries when available, then refresh in the background if needed.
- Folder headers show a small red dot while contents are still being checked and a green dot once that folder has been verified.
- Automatic refresh checks run in the background after the UI opens.
- The app does a hidden warm-up after startup to preload icon sources and pinned folder caches.
- When the startup message is enabled, the startup help appears every time the radial dock is opened until the user turns it off.
- On app launch, the radial menu opens centered on screen so users immediately see that it is running.
- Folder sub-view adapts size to item count.
- If a folder contains more than `50` items, compact list mode is used.
- Source runs store settings at `%APPDATA%\\RadialDock\\config.json`.
- Installed runs store settings and cache inside `%LocalAppData%\\RadialDock\\`.
- `Manual Refresh` runs only the checks when automatic toggle is currently off.

## CLI Modes

- `python -m radialdock.app --portable`
- `python -m radialdock.app --install`
- `python -m radialdock.app --uninstall`
- `python -m radialdock.app --install --silent`
- `python -m radialdock.app --uninstall --silent`

Install/uninstall supports:

- Windows message-box driven install choices in the packaged EXE
- Start Menu and desktop shortcuts
- an `Open after install` choice during install
- startup shortcut management
- closing a running installed `RadialDock.exe` automatically before uninstall
- a `--silent` mode that answers yes to all install questions (desktop shortcut and automatic start) and suppresses installer dialogs

When running from source (`python -m radialdock.app`), install features are still available for development, but the true copy-to-`%LocalAppData%` EXE flow is intended for the packaged build.

## Development Status

- Original step-based MVP plan is complete.
- Ongoing development is now tracked by versioned fixes/features instead of the original step plan.

## Project Layout

- `src/radialdock/app.py` entry point
- `src/radialdock/win_hotkey.py` global hotkey integration
- `src/radialdock/install.py` install/uninstall scaffold
- `src/radialdock/model.py` app settings/model scaffold
- `src/radialdock/cache.py` SQLite thumbnail cache scaffold
- `src/radialdock/shell_open.py` shell open helper
- `ui/` QML UI components
- `docs/JOURNAL.md` implementation journal
