# Radial Dock Launcher (Windows 11)

RadialDock is a PySide6 + Qt Quick launcher overlay that appears around the cursor via a global hotkey.

## MVP Status

- Original step-based MVP plan is complete.
- Current documented version: `0.11.0`
- Ongoing development is now tracked by versioned fixes/features instead of the original step plan.

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
- Step 12 complete: install/uninstall flows, Windows shortcuts, and startup toggle integration.
- Step 13 complete: packaging flow, installer naming, startup onboarding, and startup-time responsiveness improvements.

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
  - closes the group rename prompt if open
  - closes an open icon group if open
  - closes folder sub-view if open
  - otherwise closes the radial overlay
- Click the center core to open the settings panel.
- Hold the center core for 2 seconds to toggle `Group Edit Mode`.
- In `Group Edit Mode`, drag one ring item onto another to merge them into a named group.
- In normal mode, clicking a group opens a smaller radial sub-ring on top of the main dock.
- In normal mode, you can drag an item out of an open group sub-ring and drop it onto the main dock to move it back to the top level.
- Settings now include `Restart App` and `Quit App` controls for full process control.
- Settings now include single-file backup controls for exporting settings only, exporting settings plus dock items, and importing a backup.
- Settings now include an `Automatic Item Alignement` toggle so the ring can switch between even spacing and freer user-bunched placement along the circle.
- Settings include a `Close after launch` toggle to optionally dismiss the menu after opening real items.
- Settings include a capture-based shortcut picker at the top for keyboard or mouse-button launch shortcuts.
- Settings `App Control` now includes a `Launch on startup` toggle.
- Image files now use cached thumbnail previews as full-bleed visuals in the main ring and tile-mode folder view.
- Windows `.lnk` and `.url` shortcuts now use Windows shell-aware icon extraction, so shortcut icons are much more likely to match what Explorer shows.
- Image previews use square cover-cropped cached thumbnails, so they fill the UI shape without stretching.
- Missing image previews now load in the background, so folder/menu open stays responsive while thumbnails fill in.
- Folder views now open first and load refreshed contents after, while cached-only mode still opens immediately with no new scan.
- Automatic refresh checks now run in the background after the UI opens, so the dock can appear before filesystem scans finish.
- The app also does a light hidden warm-up after startup to preload current ring icon sources before the first hotkey open.
- That hidden startup warm-up now also refreshes pinned folder caches in the background when automatic folder refresh is enabled, so the first folder open after boot is less likely to stall.
- When the startup message is enabled, the startup help appears every time the radial dock is opened until the user turns it off.
- On app launch, the radial menu opens centered on screen so users immediately see that it is running.
- The startup message explains the app, the default shortcut (`Ctrl+Space`), where to change it, and how to add/remove ring items. It can be turned off.
- Folder sub-view adapts size to item count.
- If folder contains more than `50` items, compact list mode is used.
- Source runs store settings at `%APPDATA%\\RadialDock\\config.json`.
- Installed runs store settings and cache inside `%LocalAppData%\\RadialDock\\`.
- Automatic refresh settings let users avoid disk existence scans when disabled.
- `Manual Refresh` runs only the checks whose automatic toggle is currently off.
- Fresh installs start with an empty ring. Add items by dragging files, folders, or shortcuts in from Explorer.

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
- `python -m radialdock.app --install --silent`
- `python -m radialdock.app --uninstall --silent`

Install/uninstall now supports:
- Windows message-box driven install choices in the packaged EXE
- Start Menu and desktop shortcuts
- an `Open after install` choice during install
- startup shortcut management
- closing a running installed `RadialDock.exe` automatically before uninstall
- a `--silent` mode that answers yes to all install questions and suppresses installer dialogs

When running from source (`python -m radialdock.app`), install features are still available for development, but the true copy-to-`%LocalAppData%` EXE flow is intended for the packaged build.

## Build Single EXE

```powershell
.\build.ps1
```

This runs PyInstaller `--onefile`, prompts in the terminal for a version number using the last saved value from `VERSION.txt` as the default, stores the chosen version back to `VERSION.txt`, and outputs:

- `dist\RadialDockInstaller-<version>.exe` for install/uninstall and first-time setup

When installed, it copies itself to:

- `%LocalAppData%\RadialDock\RadialDock.exe`

The installed `RadialDock.exe` is the actual day-to-day launcher binary.

## Rebuild And Reinstall

For a one-command rebuild using the current version in `VERSION.txt`, followed by uninstall and reinstall of the matching latest installer:

```bash
./rebuild_reinstall.sh
```

This script:
- runs `build.ps1`
- reads the current version from `VERSION.txt`
- runs the matching installer with `--uninstall --silent`
- runs the same installer again with `--install --silent`

## Project Layout

- `src/radialdock/app.py` entry point
- `src/radialdock/win_hotkey.py` global hotkey integration
- `src/radialdock/install.py` install/uninstall scaffold
- `src/radialdock/model.py` app settings/model scaffold
- `src/radialdock/cache.py` SQLite thumbnail cache scaffold
- `src/radialdock/shell_open.py` shell open helper
- `ui/` QML UI components
- `docs/JOURNAL.md` implementation journal
