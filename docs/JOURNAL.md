# RadialDock Development Journal

## Current Step

- Current step number: **3**
- Implemented now: **Step 1 and Step 2**
- Next: **Step 3 - Radial ring layout with sample items and smoother open/close polish**

## Status Snapshot

- Step 1: Complete
- Step 2: Complete
- Step 3: In progress (initial QML ring component scaffolded)
- Steps 4-12: Pending

## Change Log

### 2026-02-27 - Change 1 (Repo bootstrap)

- Initialized git repository.
- Created folders: `src/radialdock`, `ui`, `assets`, `docs`, `.vscode`.
- Added `requirements.txt`, `pyproject.toml`, and `.gitignore`.
- Created and populated `.venv` with required dependencies.

### 2026-02-27 - Change 2 (Step 1 implementation)

- Implemented `src/radialdock/app.py` with Qt app bootstrap, QML engine setup, and context wiring.
- Added `ui/Main.qml` translucent frameless overlay window and baseline visuals.
- Added high-DPI setup and startup flow.
- Added README run instructions and VS Code interpreter settings.

### 2026-02-27 - Change 3 (Step 2 implementation)

- Implemented `src/radialdock/win_hotkey.py` using `RegisterHotKey` + native `WM_HOTKEY` handling via Qt native event filter.
- Connected hotkey activation to cursor-positioned overlay toggle.
- Added ESC/outside-click close behavior and open/close opacity animations.
- Added model/config scaffolding (`src/radialdock/model.py`) with default hotkey and refresh toggle storage.

### 2026-02-27 - Change 4 (Future-step scaffolding)

- Added placeholders for `install.py`, `cache.py`, `shell_open.py`.
- Added initial QML component files: `RadialRing.qml`, `Tile.qml`, `FolderView.qml`, `Settings.qml`.
- Added `build.ps1` for onefile PyInstaller builds.
