# RadialDock Development Journal

## Current Step

- Current step number: **12**
- Implemented now: **Step 1, Step 2, Step 3, Step 4, Step 5, Step 6, Step 7, Step 8, Step 9, Step 10, and Step 11**
- Next: **Step 12 - Self install/uninstall via the same EXE**

## Status Snapshot

- Step 1: Complete
- Step 2: Complete
- Step 3: Complete
- Step 4: Complete
- Step 5: Complete
- Step 6: Complete
- Step 7: Complete
- Step 8: Complete
- Step 9: Complete
- Step 10: Complete (new settings menu step)
- Step 11: Complete
- Step 12: In progress
- Step 13: Pending

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

### 2026-02-27 - Change 10 (Step 5 complete: external Explorer drag/drop)

- Added external drop handling in `ui/Main.qml` via `DropArea` for URL drops from Explorer.
- Added drop-hover visual state and focus-loss guard while dragging from external windows.
- Extended `ui/RadialRing.qml` with `addDroppedUrls(urls)` path ingestion.
- Added URL-to-local path conversion, item label extraction, type tagging (`file/folder/shortcut`), deterministic color selection, and duplicate-path prevention.
- Updated planning status to mark Step 5 complete and Step 6 in progress.

### 2026-02-27 - Step 5 Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space` to show the ring.
3. Open Explorer and drag a file into the ring, then release.
4. Confirm a new item appears with that file name.
5. Repeat with:
   - one folder
   - one `.lnk` shortcut
6. Drop the same path again and confirm it is not duplicated.

### 2026-02-27 - Change 11 (Step 5 regression hotfix)

- Fixed overlay auto-hide regression during external drag by removing focus-loss close behavior from `ui/Main.qml`.
- Kept close behavior through explicit actions: hotkey toggle, Esc, and click on overlay background.
- Fixed Qt warning by converting deprecated parameter-injection mouse handlers to formal function parameters in `ui/Main.qml`.

### 2026-02-27 - Step 5 Re-Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space`.
3. Drag a file/folder from Explorer toward the ring and keep holding mouse.
4. Confirm overlay stays visible while dragging (does not auto-close).
5. Drop item into ring and confirm new tile appears.

### 2026-02-27 - Change 12 (Step 6 complete: persistence in config.json)

- Extended `src/radialdock/model.py` with persisted ring item support:
  - `ringItems` property exposed to QML.
  - `saveRingItems(QVariantList)` slot to store reordered/added/removed entries.
  - Default ring items now seeded in model on first run.
  - Ring item schema now includes `color` in addition to `path`, `label`, and `kind`.
- Updated `ui/RadialRing.qml` to:
  - load initial items from `appModel.ringItems` on startup.
  - debounce-save item state back to `appModel.saveRingItems(...)` after add/reorder/remove.
- Verified backend persistence by saving to a temp config and reloading through a fresh `AppModel` instance.

### 2026-02-27 - Step 6 Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space`.
3. Make at least one change to the ring:
   - reorder an item, or
   - remove an item, or
   - drop a new file/folder from Explorer.
4. Close app process and start again:
   - `python -m radialdock.app`
5. Confirm the ring state is the same as before restart.
6. Optional config check:
   - open `%APPDATA%\\RadialDock\\config.json`
   - confirm `items` matches the visible ring order/content.

### 2026-02-27 - Change 13 (Step 7 complete: per-item icons)

- Added Windows/Qt icon extraction in `src/radialdock/model.py` using `QFileIconProvider`.
- Exposed `iconDataUrl(path, kind, label)` slot for QML to request icon images as base64 PNG data URLs.
- Added in-memory icon caching to reduce repeated icon conversion cost.
- Updated app bootstrap in `src/radialdock/app.py` to use `QApplication` (Qt Widgets support required for icon provider).
- Updated `ui/RadialRing.qml` tile delegate to render icons above labels for both default and dropped items.

### 2026-02-27 - Step 7 Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space`.
3. Confirm all ring items show icons (not text-only circles).
4. Drag a file and a folder from Explorer into the ring.
5. Confirm both new entries display icons appropriate to type.
6. Restart app and confirm icons still display for persisted items.

### 2026-02-27 - Change 14 (Step 8 complete: folder open sub-view + tile open)

- Added folder browsing backend in `src/radialdock/model.py`:
  - `listFolderEntries(folder_path, refresh_on_open)` slot returns folder contents with path/kind/icon.
  - `openPath(path)` slot wraps Windows open behavior for QML use.
  - `pathKind(path)` slot added for robust folder/file/shortcut classification.
- Updated `ui/RadialRing.qml`:
  - Clicking a ring folder item now opens an inner `FolderView`.
  - Folder items are loaded as tiles with icons.
  - Clicking a tile opens the selected file/folder.
  - Added back/close flow for folder sub-view.
- Updated `ui/FolderView.qml` and `ui/Tile.qml`:
  - Folder panel header with back button.
  - Tile click signal and stronger hover magnification.

### 2026-02-27 - Step 8 Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space`.
3. Drag a real folder from Explorer into the ring and drop it.
4. Click that folder ring item.
5. Confirm folder sub-view opens with tiles/icons for files/folders inside.
6. Click one tile and confirm Windows opens it.

### 2026-02-27 - Change 15 (Step 9 complete: thumbnail cache with SQLite + disk)

- Implemented full thumbnail cache in `src/radialdock/cache.py`:
  - SQLite metadata store (`thumbs.sqlite3`) with path + mtime key semantics.
  - Disk thumbnail outputs under cache `thumbs/`.
  - Cache lookup, render, upsert, and stale thumbnail cleanup flow.
- Integrated cache into `src/radialdock/model.py`:
  - Added `ThumbnailCache` usage for image files in folder views.
  - Folder listing now returns thumbnail URI for image files and icon fallback for non-image entries.
  - Wired refresh parameter through listing path for future refresh-on-open behavior.
- Verified cache generation and metadata write in local runtime checks.

### 2026-02-27 - Step 9 Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space`.
3. Add/open a folder containing image files (`.png`/`.jpg`) in the ring.
4. Confirm image entries display thumbnail previews in folder view tiles.
5. Inspect cache paths:
   - `%APPDATA%\\RadialDock\\cache\\thumbs.sqlite3`
   - `%APPDATA%\\RadialDock\\cache\\thumbs\\`
6. Confirm both database and thumbnail files exist after viewing the folder.

### 2026-02-27 - Change 16 (UI interaction tweaks before Step 10)

- Implemented universal right-click back behavior in `ui/Main.qml`:
  - If folder view is open, right-click closes folder view and returns to radial menu.
  - If radial menu is showing, right-click closes the overlay.
- Removed folder view back button from `ui/FolderView.qml`; right-click is now the primary back action.
- Added adaptive folder panel sizing in `ui/RadialRing.qml`:
  - Folder panel scales up/down by item count.
  - Overlay/stage sizing now adapts in `ui/Main.qml`.
  - Window is clamped within screen bounds so expanded panel stays on-screen.
- Added compact folder list fallback in `ui/FolderView.qml` + `ui/RadialRing.qml`:
  - If folder item count is greater than threshold, show compact list with small icons.
  - Threshold is currently `folderListFallbackThreshold: 50` in `ui/RadialRing.qml`.

### 2026-02-27 - UI Tweak Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space`, open a folder from ring, then right-click anywhere on UI.
3. Confirm folder view closes and radial menu remains visible.
4. Right-click again and confirm radial overlay closes.
5. Open a folder with moderate item count and confirm panel sizes to show all items immediately.
6. Open a folder with more than 50 items and confirm compact list mode with small icons is used.

### 2026-02-27 - Change 17 (Folder header text alignment polish)

- Updated `ui/FolderView.qml` header layout so `Right click: Back` is centered between folder title (left) and mode label (right).
- Reduced back hint font size slightly (`10` -> `9`) to keep it inside bounds on smaller widths.

### 2026-02-27 - Change 18 (Folder-back animation smoothing)

- Added folder-back animation handoff between `ui/RadialRing.qml` and `ui/Main.qml`.
- Returning from folder view now replays the same ring open animation sequence (fade/scale/reveal) used by hotkey open.
- This removes the twitchy icon transition previously seen when closing folder sub-view.

### 2026-02-27 - Change 19 (Animation speed tweak: 2x faster)

- Updated `ui/Main.qml` with `animationSpeedScale` and set it to `0.5`.
- Main open/back animation timings are now twice as fast.
- Close and stage resize timings were also scaled by the same factor for consistency.

### 2026-02-27 - Change 20 (Step 10 complete: center settings menu + persisted runtime preferences)

- Added a new step: center-click settings menu as a first-class runtime control hub.
- Implemented full settings panel in `ui/Settings.qml` and wired it from `ui/RadialRing.qml` center core click/hover.
- Added settings features:
  - Clear all ring items with explicit confirmation.
  - Animation speed scale input (`0.1` to `10.0`) with guidance (lower=faster, higher=slower).
  - Toggle to disable animations for instant transitions.
  - Compact list fallback threshold input for folder view.
  - Reset quick settings to defaults with confirmation.
- Persisted settings in user config via `src/radialdock/model.py`:
  - `animation_speed_scale`
  - `animations_enabled`
  - `folder_compact_threshold`
  - existing `refresh_on_open`
- Added model slots/properties to support settings UI:
  - `clearRingItems()`
  - `resetQuickSettings()`
  - `animationSpeedScale`, `animationsEnabled`, `folderCompactThreshold` properties
- Updated `ui/Main.qml` and `ui/RadialRing.qml` to consume persisted settings at runtime.
- Decision: settings are stored per user/installation in `%APPDATA%\\RadialDock\\config.json` (not in source files).

### 2026-02-27 - Change 21 (Settings UX polish pass)

- Fixed settings-back transition jitter by routing settings close through the same reopen animation path used for radial launch:
  - Added `settingsBackRequested` signal in `ui/RadialRing.qml`.
  - Added `animateBackFromSettings()` in `ui/Main.qml`.
- Removed settings panel close button (right-click back remains the universal exit/back action).
- Replaced default white button styling in `ui/Settings.qml` with a dark custom button component for better contrast with light text.

### 2026-02-27 - Change 22 (Settings alignment + style warning fix)

- Renamed settings toggle label from `Disable animations` to `Animations` with standard on/off behavior.
- Aligned all right-side helper texts vertically to center with their row controls in `ui/Settings.qml`.
- Fixed Qt native-style customization warnings by replacing styled `Button` usage with a custom `ActionButton` rectangle component.

### 2026-02-27 - Change 23 (Dedicated radial icon move speed parameter)

- Added `radialItemMoveBaseDuration` in `ui/RadialRing.qml` as a single tuning parameter for icon move/reorder speed around the ring.
- The value is still scaled by the global `animationSpeedScale` setting, so settings-based speed control continues to apply.

### 2026-02-27 - Change 24 (Double-move animation bugfix after drop/remove)

- Root cause: after local QML mutations (drop/remove), persistence save triggered `ringItemsChanged`, and the ring immediately reloaded its model from backend, causing a second movement pass.
- Fix: added `skipNextModelSync` guard in `ui/RadialRing.qml` to ignore the immediate self-originated `ringItemsChanged` following `saveRingItems(...)`.
- Result: external drop/remove now performs a single movement transition instead of a double movement.

### 2026-02-27 - Change 25 (Center-safe drag behavior)

- Hardened drag behavior in `ui/RadialRing.qml` to ignore the center region during rearrange:
  - Added `centerIgnoreRadius` dead-zone.
  - While pointer is in center zone, reorder target locks to dragged item and remove state is suppressed.
- Switched remove/reorder decision inputs to pointer position on drag/release for more stable intent handling.
- Disabled center settings click target while dragging (`ring.draggedIndex < 0`) to avoid interaction interference.

### 2026-02-27 - Change 26 (Drag pickup offset bugfix)

- Fixed intermittent icon pickup "pop" in `ui/RadialRing.qml`.
- Root cause: per-item drag anchor values could stay stale between drags.
- Fix: on each press, drag anchor is reinitialized to current slot position before calculating pointer offset; anchor is reset again after release/cancel.

### 2026-02-27 - Step 10 Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space` and hover center core; confirm hint appears.
3. Click center to open settings panel.
4. Change animation speed, close settings, and confirm animation timing changes.
5. Toggle animations off; confirm transitions become instant.
6. Set compact threshold to a low value (for test), open folder, and confirm compact list mode triggers.
7. Use `Clear All Items` and `Reset Settings To Default` and confirm each asks for confirmation.
8. Restart app and confirm settings persist from `%APPDATA%\\RadialDock\\config.json`.

### 2026-02-28 - Change 27 (Step 11 complete: automatic refresh controls)

- Reworked refresh behavior in `src/radialdock/model.py`:
  - Split the old single refresh flag into:
    - `automatic_icon_refresh`
    - `automatic_folder_refresh`
  - Added persisted folder listing cache (`folder_cache`) in user config.
  - Added `refreshEnabledData()` to run only enabled checks when the radial menu opens.
  - Added `manualRefreshEnabled()` for the settings panel manual refresh action.
  - If automatic icon refresh is enabled, missing main ring items are removed on next menu open.
  - If automatic folder refresh is enabled, ring folder caches are rescanned on next menu open.
  - If automatic folder refresh is disabled, folder view uses cached listings only and does not touch disk.
- Updated `ui/Main.qml` to trigger enabled refresh checks each time the overlay opens.
- Updated `ui/RadialRing.qml` to consume the new folder refresh property and expanded settings panel sizing.
- Expanded `ui/Settings.qml` with:
  - `Automatic icon refresh` toggle
  - `Automatic folder refresh` toggle
  - `Manual Refresh` action
  - helper text explaining disk-check behavior
- Fixed settings switch state sync so reset/default actions and backend updates keep the toggles visually accurate.
- Deferred `watchdog` file watching for now; Step 11 MVP is satisfied without background watchers.

### 2026-02-28 - Step 11 Verification Instructions (Git Bash)

1. In repo root:
   - `source .venv/Scripts/activate`
   - `python -m radialdock.app`
2. Press `Ctrl+Space`, click the center core, and confirm settings shows:
   - `Automatic icon refresh`
   - `Automatic folder refresh`
   - `Manual Refresh`
3. Leave `Automatic icon refresh` on, close settings, delete one real file currently in the ring, then open the radial menu again.
4. Confirm the missing ring item disappears automatically on that next open.
5. Add/open a real folder in the ring so it has a cached listing, then turn `Automatic folder refresh` off.
6. Change that folder in Explorer (add or remove a file), reopen the folder from the ring, and confirm it still shows the cached listing.
7. Turn `Automatic folder refresh` back on or click `Manual Refresh` with it enabled.
8. Reopen the same folder and confirm the folder contents update to the real current state.

### 2026-02-28 - Change 28 (Manual refresh behavior correction)

- Updated `src/radialdock/model.py` so `Manual Refresh` now refreshes only the areas whose automatic refresh toggle is currently off.
- Automatic refresh types that are still enabled are skipped by `Manual Refresh` because they already run on menu open.
- Updated `ui/Settings.qml` helper text to explain the corrected behavior:
  - automatic-off means that category waits for manual refresh
  - if both automatic toggles are on, `Manual Refresh` does nothing

### 2026-02-28 - Change 29 (Settings helper text spacing tweak)

- Reduced line spacing for the two longer automatic refresh helper texts in `ui/Settings.qml`.
- This keeps the wrapped text more compact vertically and avoids the slight overlap in those rows.
