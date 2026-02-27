# RadialDock Development Journal

## Current Step

- Current step number: **5**
- Implemented now: **Step 1, Step 2, Step 3, and Step 4**
- Next: **Step 5 - External Explorer drag/drop into overlay**

## Status Snapshot

- Step 1: Complete
- Step 2: Complete
- Step 3: Complete
- Step 4: Complete
- Step 5: In progress
- Steps 6-12: Pending

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

### 2026-02-27 - Change 5 (Development planning file)

- Added `docs/DEV_PLAN.md` as the primary planning and tracking document.
- Captured full MVP roadmap (Steps 1-12) with status, exit criteria, and detailed execution plan.
- Logged current state: Step 1 and Step 2 complete, Step 3 in progress.

### 2026-02-27 - Change 6 (Verification handoff rule)

- Added a standing rule to provide simple user test instructions after each completed step.
- Added protocol details in `docs/DEV_PLAN.md` under quality gates/verification.

### 2026-02-27 - Change 7 (Step 3 complete: radial layout + motion polish)

- Upgraded `ui/Main.qml` overlay transitions with smoother fade/scale open and close motion.
- Added ring `openProgress` driven animation flow to support staged reveal and collapse.
- Upgraded `ui/RadialRing.qml` with improved geometry, sequential reveal feel, and visual ring layers.
- Marked Step 3 as complete in planning docs and moved active work to Step 4.

### 2026-02-27 - Step 3 Verification Instructions

1. Open PowerShell in repo root and activate venv: `.\.venv\Scripts\Activate.ps1`.
2. Run app: `python -m radialdock.app`.
3. Press `Ctrl+Space` and check overlay appears around cursor.
4. Confirm radial buttons animate outward from center with a smooth sequence.
5. Close overlay using:
   - `Ctrl+Space` again
   - `Esc`
   - click outside the ring
6. Confirm each close method fades/scales out cleanly without freezing.

### 2026-02-27 - Change 8 (Post-Step 3 bugfix + terminal docs update)

- Fixed QML runtime error in `ui/RadialRing.qml` by declaring `required property int index` in the delegate.
- Removed deprecated Qt DPI attributes in `src/radialdock/app.py` and switched to DPI rounding policy setup for Qt 6.
- Updated `README.md` run instructions to prefer Git Bash (`source .venv/Scripts/activate`) with PowerShell as fallback.

### 2026-02-27 - Hotfix Verification Instructions (Git Bash)

1. In repo root, activate venv:
   - `source .venv/Scripts/activate`
2. Start app:
   - `python -m radialdock.app`
3. Confirm there are no `RadialRing.qml ... index is not defined` errors in terminal.
4. Press `Ctrl+Space` and confirm overlay appears and animates.

### 2026-02-27 - Change 9 (Step 4 complete: internal drag reorder + drag-out remove)

- Reworked `ui/RadialRing.qml` to use a mutable `ListModel` ring item source.
- Implemented in-ring drag reorder with live hover target calculation and animated neighbor shifts.
- Implemented drag-out remove behavior using distance threshold, remove prompt, and subtle shrink/fade before model removal.
- Added drag-state helpers (`startDrag`, `updateDrag`, `finishDrag`) and cleanup timer-driven removal.
- Updated planning status to mark Step 4 complete and Step 5 in progress.

### 2026-02-27 - Step 4 Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space` to open the ring.
3. Click and hold one item, drag it across neighboring items, then release.
4. Confirm neighboring items shift smoothly and the dropped item keeps its new position.
5. Click and hold one item, drag it well outside the ring until center text changes to remove prompt, then release.
6. Confirm item removes with a short smooth fade/shrink effect.
