# RadialDock Development Journal

## Current Version

- Current version: **0.12.3**
- Versioning mode: **Version-based tracking**
- Original step-based plan: **Complete through Step 13**
- Next tracking style: **Journal entries by version and targeted fixes/features**

## Status Snapshot

- Original development plan: Complete
- `docs/DEV_PLAN.md`: Archived for reference only
- Ongoing work: Post-plan fixes, polish, and new features tracked here
- Current documented version: `0.12.3`

## Change Log

### 2026-04-06 - Change 88 (Non-image icons now resolve placeholder-first in the background)

- Changed `iconDataUrl()` so non-image file, folder, and shortcut icons no longer block the UI on first resolve.
- The UI now gets a cheap placeholder immediately, while the real Windows icon is resolved on the background worker and swapped in afterward.
- This reduces the cold-boot hitch where the first folder open could still stall on synchronous shell icon lookup even after folder-entry refresh had been moved off the visible path.

### 2026-04-06 - Change 87 (Folder views open from cache immediately with refresh-state indicator)

- Changed folder opening so the UI uses cached folder entries immediately when available instead of waiting for the refresh result first.
- Added folder refresh state tracking in the backend so folders can be marked as `pending`, `checking`, `checked`, or `disabled`.
- Folder headers now show a small red dot while the folder contents are still being checked and a small green dot once the folder has been verified.
- If a folder cache is refreshed by the app-wide background scan while that folder is open, the visible folder view now updates live.

### 2026-04-06 - Change 86 (Build script uses absolute PyInstaller data paths)

- Fixed a packaging error where PyInstaller could not find `ui`, `assets`, or `VERSION.txt` after the generated `.spec` was moved under `build\spec`.
- `build.ps1` now resolves the source tree, entry script, UI directory, assets directory, and version file to absolute paths before invoking PyInstaller.
- This keeps the cleaned-up `build\spec` flow while avoiding relative-path breakage in the generated spec.

### 2026-04-06 - Change 85 (Optional file extension display in dock labels)

- Added a persisted `Show file extensions` setting under the visual dock settings.
- By default, file and shortcut labels now hide endings like `.lnk`, `.url`, and other file extensions in the dock UI.
- Turning the setting on restores full labels with extensions.
- This is a display-only change: stored item labels and paths are not rewritten.

### 2026-04-06 - Change 84 (Build script now bootstraps and uses local .venv)

- Updated `build.ps1` so it no longer assumes `.venv` already exists.
- The build now creates `.venv` automatically if it is missing, using a local Python launcher from `py` or `python`.
- Before packaging, the build installs `requirements.txt` and the local editable package into that `.venv`.
- This keeps build dependencies out of the user's global Python installation while making the build flow more self-contained.

### 2026-04-06 - Change 83 (README reordered for clearer build and usage flow)

- Reorganized `README.md` so it starts with a short explanation of what RadialDock is.
- Moved installer build and `rebuild_reinstall.sh` usage above the longer manual source-run commands.
- Moved the longer feature and status/reference sections lower in the document so the primary "how to use" path is easier to follow.

### 2026-04-06 - Change 82 (Build script stops leaving versioned .spec files in repo root)

- Cleaned up `build.ps1` so PyInstaller-generated versioned installer `.spec` files are no longer left in the repo root.
- The build now routes generated spec/work files through the `build` directory and removes the generated versioned installer `.spec` after the build finishes.
- Legacy root-level `RadialDockInstaller-*.spec` files are also cleaned up automatically on build.

### 2026-04-06 - Change 81 (Non-interactive build version from VERSION.txt)

- Removed the interactive version prompt from `build.ps1`.
- The build script now reads the version directly from `VERSION.txt` and does not rewrite that file.
- If `VERSION.txt` is missing or empty, the build now fails fast with a clear error.
- This makes local builds simpler and also matches the intended future CI/signing workflow better.

### 2026-03-11 - Change 80 (Version bump to 0.12.3 + decorative ring alignment)

- Confirmed the official documented version is now `0.12.3`.
- Aligned the two decorative semi-opaque rings in the main dock to the actual item orbit:
  - the inner decorative ring now touches the inner edge of the dock items
  - the outer decorative ring now touches the outer edge of the dock items
- The decorative ring sizes now derive from `orbitRadius` and item size instead of fixed percentages.

### 2026-03-10 - Change 79 (Separate click intent from drag intent)

- Hardened input handling for ring items and group items so a press no longer immediately starts a drag.
- Dragging now begins only after movement crosses a small threshold.
- Result:
  - off-center clicks no longer nudge the icon before opening it
  - slight drag attempts no longer accidentally open the item as a click
  - once a drag has started, release is treated as a drag finish instead of an open action

### 2026-03-10 - Change 78 (Version bump to 0.12.1)

- Confirmed the official documented version is now `0.12.1`.
- Synced `VERSION.txt`, the journal, and README to version `0.12.1`.

### 2026-03-10 - Change 77 (Fix first toggle-off jump for auto alignment)

- Fixed the first-time toggle edge case for `Automatic Item Alignement`.
- Root cause: the ring's local alignment state was still using a live binding to the backend setting, so on the first toggle-off it could already read as false before the transition handler had a chance to snapshot the current aligned positions.
- The ring now keeps its own local alignment state and refreshes it explicitly from the model, so the first transition to free-placement mode preserves the current visible layout correctly.

### 2026-03-10 - Change 76 (Keep visible positions when turning off auto alignment)

- Fixed the transition when `Automatic Item Alignement` is turned off.
- The ring now snapshots the current evenly spaced visible positions into each top-level item's stored angle before switching to free placement mode.
- Result: items no longer jump to unrelated positions when the toggle is turned off.

### 2026-03-10 - Change 75 (Version bump to 0.11.0 + automatic item alignment toggle)

- Confirmed the official documented version is now `0.11.0`.
- Added `Automatic Item Alignement` to the settings panel, placed under `Close after launch`.
- The toggle defaults to on:
  - on = ring items spread evenly around the dock
  - off = items still stay on the circular path, but users can bunch them on one side or place them close together
- Top-level ring items now persist their angular position so freer placement survives restarts and export/import.

### 2026-03-10 - Change 74 (Version bump to 0.10.11 + settings backup/import)

- Confirmed the official documented version is now `0.10.11`.
- Added single-file settings backup/import support:
  - export settings only
  - export settings and dock items
  - import backup
- Backup/import is available from the bottom of the settings panel and uses native file dialogs.
- Settings-only imports leave the current dock items unchanged.
- Settings-and-dock exports/imports include the current pinned ring items in the same backup file.

### 2026-03-10 - Change 73 (Startup folder cache warm-up)

- Extended `warmStartupCaches()` so startup warm-up now also prebuilds folder cache entries in the background when automatic folder refresh is enabled.
- This moves the first folder refresh after boot into the hidden startup phase instead of waiting for the user's first folder open.
- If automatic folder refresh is off, this warm-up still skips folder scans entirely, preserving the no-disk-touch behavior for that setting.

### 2026-03-04 - Change 72 (Version bump to 0.10.10)

- Confirmed the official documented version is now `0.10.10`.
- Synced `VERSION.txt`, the journal, and README to version `0.10.10`.

### 2026-03-04 - Change 71 (Group preview count + white-dot simplification)

- Updated the miniature main-ring group preview so it now renders one preview dot per grouped item instead of stopping at three.
- Removed the old center dot from the miniature group preview.
- Simplified the preview visuals so the small group-preview dots are now minimal white dots instead of color-coded dots.

### 2026-03-04 - Change 70 (Miniature group menu preview on group icons)

- Replaced the old stacked indicator balls on grouped main-ring icons with a miniature circular group-preview motif.
- Group icons in the main ring now show:
  - a small circular mini-preview shell
  - a few tiny dots arranged inside it to suggest the grouped contents
- This keeps the group icon visually closer to the actual opened group sub-ring and makes the group state more readable at a glance.

### 2026-03-04 - Change 69 (Version bump to 0.10.9)

- Confirmed the official documented version is now `0.10.9`.
- Synced the journal and README to version `0.10.9`.

### 2026-03-04 - Change 68 (Fix repeated drag-out duplication from groups)

- Fixed a bug when dragging multiple items out of the same open group in sequence.
- Root cause: the open group's tracked top-level ring index could go stale when the first moved item was inserted before the group in the main ring.
- That stale index caused later drag-outs to rewrite the wrong top-level item, which could duplicate groups and make previously moved items disappear.
- The move-out path now updates the group state and adjusts the tracked group index correctly before the next drag.

### 2026-03-04 - Change 67 (Drag items out of groups back to main ring)

- Added normal-mode drag support for items inside an open group sub-ring.
- Users can now drag a group item out of the small group ring and release it onto the main dock area to move it back to the top-level radial ring.
- Group persistence now updates immediately when an item is moved out:
  - groups shrink correctly
  - a 1-item group collapses back into a normal single item
  - an empty group is removed
- Group folder back-navigation state now also tracks the source group index so this new move-out behavior stays consistent with folder return behavior.

### 2026-03-04 - Change 66 (Center group title in group overlay)

- Moved the open group title from the top edge of the group sub-ring into the visual center of the group overlay.
- The group title now sits in the center hub area, matching the intended smaller radial menu layout.

### 2026-03-04 - Change 65 (Silent installer mode + launch-after-install option)

- Added `--silent` support to `python -m radialdock.app --install` and `--uninstall`.
- Silent install now answers yes to all installer questions and suppresses normal install/uninstall info dialogs.
- Added a new install-time question: `Open RadialDock after installation?`
  - it appears after the desktop shortcut question and before the startup question
  - in silent mode, it is always treated as yes
- Post-install launch now uses the same shortcut-launch path, so it opens like a normal first launch.
- Updated `rebuild_reinstall.sh` to use `--uninstall --silent` and `--install --silent` for a faster rebuild loop.

### 2026-03-04 - Change 64 (Version bump to 0.10.6)

- Confirmed the official documented version is now `0.10.6`.
- Synced the journal and README to version `0.10.6`.

### 2026-03-04 - Change 63 (Group UI follow-up fixes)

- Fixed duplicate group labels in the main ring by preventing the normal non-group text/icon branch from rendering on grouped items.
- Fixed group overlay positioning so the opened group sub-ring is centered directly on the clicked group icon instead of being clamped inward toward the main dock center.
- Fixed group sub-ring icon rendering by binding the delegate directly to the live `groupEntries` array instead of relying on the prior brittle delegate data binding.
- Fixed folder back-navigation for folders opened from inside groups:
  - right click now returns from the folder view back into the originating group
  - it no longer jumps straight back to the main ring in that path

### 2026-03-04 - Change 62 (Icon groups + group edit mode)

- Added grouped dock items as a persisted top-level item type with nested child items in `src/radialdock/model.py`.
- Ring item refresh and folder-cache refresh now traverse grouped items as well, so grouped folders/files participate in the same refresh system as normal ring items.
- Added a new `Group Edit Mode` in `ui/RadialRing.qml`:
  - hold the center core for 2 seconds to toggle it on/off
  - the center core turns red while active
  - dragging one ring item onto another now merges them into a group instead of reordering
- New groups can be named immediately, and existing group names can be changed by clicking the group while `Group Edit Mode` is active.
- Clicking a group in normal mode now opens a smaller radial sub-ring on top of the main dock.
- Group entries launch and open folders using the same behavior as normal main-ring items.
- Updated `ui/Main.qml` back-action flow so right click closes group sub-rings and the group naming prompt before other views.

### 2026-03-04 - Change 61 (Version bump to 0.9.5 + rebuild helper)

- Confirmed the official documented version is now `0.9.5`.
- Synced the journal and README to version `0.9.5`.
- Added `rebuild_reinstall.sh` at the repo root for Git Bash use.
- The helper script now:
  - runs `build.ps1`
  - reads the current version from `VERSION.txt`
  - runs the matching installer with `--uninstall`
  - runs the same installer again with `--install`

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

### 2026-02-28 - Change 30 (Settings app control actions)

- Added app lifecycle controls to the bottom of `ui/Settings.qml` in a dedicated `App Control` section:
  - `Restart App`
  - `Quit App`
- Added backend slots in `src/radialdock/app.py`:
  - `quitApp()`
  - `restartApp()`
- `Restart App` launches a new instance using the current launch mode/args, then exits the current process.
- Increased settings panel height in `ui/RadialRing.qml` so the new controls fit without crowding.

### 2026-02-28 - Change 31 (Clean shutdown QML null-guard fix)

- Fixed shutdown-time QML warnings triggered after `Quit App`.
- Root cause: on teardown, `appModel`/`backend` context properties can become `null` before bindings stop evaluating.
- Updated `ui/Main.qml`, `ui/RadialRing.qml`, and `ui/Settings.qml` to guard against both:
  - `undefined`
  - `null`
- Result: quitting the app should no longer print property access errors for `animationSpeedScale`, `animationsEnabled`, `folderCompactThreshold`, or `iconDataUrl`.

### 2026-02-28 - Change 32 (Single main reveal animation path)

- Consolidated the main radial-menu return/open transition in `ui/Main.qml` into one shared function: `playMainRingReveal()`.
- Returning from folder view and settings view now routes through the same shared reveal path via `returnToMainRing(...)`.
- Added `mainRevealActive` state in `ui/Main.qml` so the return/open transition uses only the main reveal animation.
- Updated `ui/RadialRing.qml` to disable icon position (`x`/`y`) motion behaviors while the main reveal is active.
- Result: when coming back from folder/settings to the main radial menu, the icons should snap into their base layout first and then use the single shared main reveal animation, without the extra wiggle-style position animation.

### 2026-02-28 - Change 33 (Smooth backdrop growth, instant panel resize)

- Removed the stage width/height resize animation in `ui/Main.qml` when opening larger folder/settings views.
- Added a dedicated circular backdrop size animation instead:
  - the content area resizes immediately
  - the round menu background expands smoothly to the new size
- This reduces the jerky resize/shake effect when opening settings or larger folder panels while preserving a smoother visual transition.

### 2026-02-28 - Change 34 (No backdrop shrink animation on return + tuning knob)

- Updated `ui/Main.qml` so the circular backdrop resize snaps back immediately when returning from:
  - folder view
  - settings view
- The return path now goes straight into the main ring reveal animation without a second backdrop shrink animation.
- Added a dedicated tuning parameter for large-view backdrop growth speed:
  - `backdropResizeBaseDuration`
- This controls the circle expansion speed when opening larger views and is still scaled by the global `animationSpeedScale` setting.

### 2026-02-28 - Change 35 (Backdrop can stretch for rectangular views again)

- Updated the main backdrop in `ui/Main.qml` to animate width and height separately instead of staying a fixed circle.
- The background can now widen or grow taller to better cover rectangular panels like the settings view.
- The shape still keeps rounded ends using `radius: Math.min(width, height) / 2`, so it becomes an oval/capsule instead of a sharp rectangle.
- Return-to-main behavior still snaps the backdrop back immediately before the main reveal animation.

### 2026-02-28 - Change 36 (Optional close-after-launch behavior)

- Added a persisted `Close after launch` setting in `src/radialdock/model.py` (default: on).
- Added a new settings toggle in `ui/Settings.qml` under `Automatic folder refresh`.
- Behavior when enabled:
  - opening a non-folder ring item hides the radial menu immediately after launch
  - opening an item from inside folder view also hides the radial menu immediately after launch
  - opening a folder from the main ring does not close the menu, so the folder view can still open
- Added `requestHide()` to `src/radialdock/app.py` so QML can dismiss the overlay after successful launches.
- Increased settings panel height in `ui/RadialRing.qml` to fit the additional row.

### 2026-02-28 - Change 37 (Reset to main view after overlay closes)

- Fixed overlay state so the next menu open always starts from the main radial view after the overlay is closed.
- Added `resetToMainView()` in `ui/RadialRing.qml` to clear:
  - open folder view
  - open settings view
  - folder title / entries
  - transient drag state
- Wired `ui/Main.qml` to call that reset after the close animation finishes.
- Result: if a launched item closes the menu from inside folder view, reopening the menu no longer returns to that old folder state.

### 2026-02-28 - Change 38 (Reset to main view on reopen as hard guarantee)

- Added a second state reset in `ui/Main.qml` inside `showAtCursor(...)`.
- The overlay now resets `ringWidget` to the main radial view before positioning and replaying the open animation.
- This guarantees every hotkey reopen starts from the main ring, even if a previous close path did not fully settle before the next open.

### 2026-02-28 - Change 39 (Full-bleed image previews for image files)

- Updated `src/radialdock/model.py` so `iconDataUrl(...)` returns cached thumbnail URIs for image files instead of shell icons.
- This reuses the existing thumbnail cache for image-based ring items.
- Updated `ui/RadialRing.qml`:
  - image files in the main ring now render as large full-bleed previews inside the icon tile area
  - non-image files/folders keep the existing icon layout
- Updated `ui/Tile.qml` and `ui/FolderView.qml`:
  - tile-mode folder entries now render image files as full-bleed previews across the full tile area
  - non-image entries keep the existing centered icon layout
- Added a small bottom label overlay for full-bleed image previews so the item name remains visible.

### 2026-02-28 - Change 40 (Rounded masking + square cover thumbnails)

- Updated `src/radialdock/cache.py` thumbnail generation to use square cover-cropped previews via `ImageOps.fit(...)`.
- The cached preview now keeps the original aspect ratio and fills the target square:
  - wider images crop left/right
  - taller images crop top/bottom
  - no stretching is introduced
- Added a thumbnail render version token so older non-cover cached previews are invalidated and regenerated.
- Updated `ui/RadialRing.qml` and `ui/Tile.qml` to use rounded masking:
  - main ring image previews are clipped to the round icon shape
  - tile-mode image previews are clipped to the existing rounded tile corners

### 2026-02-28 - Change 41 (Radial image label kept as overlay)

- Fixed the radial-menu image preview label so it is no longer composited inside the masked preview layer.
- In `ui/RadialRing.qml`, the filename text for image previews now sits outside the masked image host.
- Result: the text remains a normal overlay on top of the image instead of looking like part of the cached preview itself.

### 2026-02-28 - Change 42 (Fast thumbnail loading pass: async + on-demand)

- Implemented the first four thumbnail speed optimizations.
- In `src/radialdock/model.py`:
  - image preview generation is no longer done synchronously on the UI path
  - missing thumbnails now return a fast fallback immediately and queue background generation
  - added `previewVersion` so QML can refresh when a background thumbnail finishes
  - image previews use one shared square size (`DEFAULT_PREVIEW_SIZE`) for both ring and tile view
- In `src/radialdock/cache.py`:
  - added `peek_thumbnail_uri(...)` so cache hits can be returned immediately without triggering generation
- In `ui/RadialRing.qml`, `ui/Tile.qml`, and `ui/FolderView.qml`:
  - image/icon sources now resolve on demand from the backend instead of being precomputed for every folder entry
  - visible delegates refresh automatically when the async thumbnail becomes available
- In `src/radialdock/model.py` folder entry building:
  - folder listing no longer pre-generates thumbnails while constructing the folder model
  - this removes the old “wait for folder entries to finish preview work before the view feels ready” path
- Result:
  - menu/folder opens should feel faster
  - cached previews display immediately if they already exist
  - uncached previews appear shortly after, without blocking the UI thread

### 2026-02-28 - Change 43 (Folder view opens first, entries load after)

- Removed the remaining synchronous folder-open hitch by changing the folder-open flow in `ui/RadialRing.qml`.
- Folder behavior is now:
  - the folder panel opens immediately
  - if automatic folder refresh is on, the entry list is loaded asynchronously in the backend
  - if automatic folder refresh is off, cached entries are used immediately and no refresh work is triggered
- Added `requestFolderEntries(...)` and `folderEntriesReady` in `src/radialdock/model.py`.
- Added a small `Loading folder...` state in `ui/FolderView.qml` for the brief async load window when needed.
- The existing settings rule remains intact:
  - automatic folder refresh off = no new folder scan on open
  - manual refresh or re-enabling automatic refresh is required to update the cached listing

### 2026-02-28 - Change 44 (Custom shortcut setting with runtime rebind)

- Added a persisted `hotkey` property to `src/radialdock/model.py`.
- Added a custom shortcut editor at the top of `ui/Settings.qml`:
  - text field
  - `Apply` button
  - success/error status line
- Added runtime hotkey rebinding in `src/radialdock/app.py` via `trySetHotkey(...)`.
- The app now validates and applies shortcut changes immediately without requiring a restart.
- Expanded `src/radialdock/win_hotkey.py`:
  - single-key shortcuts are now supported (modifiers are no longer required)
  - keyboard combinations still work
  - mouse-button shortcuts are supported via a global low-level mouse hook
- Supported examples include:
  - `Ctrl+Space`
  - `F8`
  - `A`
  - `MouseLeft`
  - `MouseRight`
  - `MouseMiddle`
  - `MouseX1`
  - `MouseX2`

### 2026-02-28 - Change 45 (Shortcut capture UI polish)

- Replaced manual hotkey text entry in `ui/Settings.qml` with a capture-based shortcut picker.
- New behavior:
  - click the shortcut box
  - press the next key, key combination, or mouse button
  - the shortcut is applied immediately
- Removed the old `Apply` button.
- Added a shortcut-only `Reset` button that restores just the shortcut to `Ctrl+Space`.
- Moved the shortcut helper text below the shortcut row and added a separator below it for a cleaner layout.
- The existing full `Reset Settings To Default` flow still resets the shortcut too, and now re-applies it live through the backend hotkey manager.

### 2026-02-28 - Change 46 (Protect against left/right mouse launch shortcuts)

- Added a launch-shortcut safeguard in `src/radialdock/app.py`.
- `MouseLeft` and `MouseRight` are now rejected as launcher shortcuts because they are reserved for UI interaction.
- If the user tries to set one, the shortcut is ignored and the status line reports the reason.
- If an older saved config contains one of those values, startup now falls back to `Ctrl+Space` automatically.
- Updated the shortcut helper text in `ui/Settings.qml` to make that restriction explicit.

### 2026-03-01 - Change 47 (Step 12 complete: install/uninstall + startup integration)

- Replaced the installer scaffold in `src/radialdock/install.py` with a real Windows install layer:
  - installed marker metadata
  - Start Menu shortcut creation
  - desktop shortcut creation
  - startup shortcut creation/removal
  - safe uninstall cleanup
- Packaged EXE behavior now supports install/uninstall from the same EXE:
  - `--install`
  - `--uninstall`
  - running an external packaged EXE with no flags can offer install/uninstall via Windows message boxes
- Added a live startup toggle to the app settings in `ui/Settings.qml` under `App Control`.
- Added `launchOnStartupEnabled` to `src/radialdock/app.py` so the running app can create/remove the startup shortcut without reinstalling.
- Full reset/default behavior remains focused on app quick settings; startup is managed as a separate system integration toggle.

### 2026-03-01 - Step 12 Verification Instructions (Git Bash)

1. Build the EXE:
   - `./build.ps1`
2. Run the installer:
   - `dist/RadialDockInstaller.exe --install`
3. Confirm the installer asks about:
   - Start Menu shortcut
   - desktop shortcut
   - start on Windows login
4. Confirm the install marker appears in `%LocalAppData%\\RadialDock`.
5. Launch the app, open settings, and go to `App Control`.
6. Toggle `Launch on startup` on and off and confirm the startup shortcut is created/removed in the Windows Startup folder.
7. Run the uninstaller:
   - `dist/RadialDockInstaller.exe --uninstall`
8. Confirm shortcuts and the install directory are removed.

### 2026-03-01 - Change 48 (Packaged UI path fix + installer rename)

- Fixed packaged resource loading in `src/radialdock/app.py`:
  - when running as a frozen PyInstaller app, the UI now loads from `sys._MEIPASS\\ui`
  - this prevents the installed EXE from failing to find bundled QML files and exiting shortly after launch
- Updated `build.ps1` so the distributable is now named `RadialDockInstaller.exe`.
- Kept the installed runtime app name as `RadialDock.exe` under `%LocalAppData%\\RadialDock`.
- Updated documentation and verification instructions to use the new installer filename.

### 2026-03-01 - Change 49 (Installed runtime state isolation + uninstall auto-close)

- Updated `src/radialdock/model.py` so the installed frozen runtime (`%LocalAppData%\\RadialDock\\RadialDock.exe`) now stores:
  - `config.json`
  - cache data
  inside `%LocalAppData%\\RadialDock`
- Source runs still use `%APPDATA%\\RadialDock`, so dev/test state no longer leaks into the installed runtime.
- Updated `src/radialdock/install.py` so uninstall now force-closes any running installed `RadialDock.exe` before removing files.
- Result:
  - uninstall can proceed without the user manually quitting first
  - uninstall/reinstall now starts from a clean installed state because the runtime config and cache live inside the removable install folder

### 2026-03-01 - Change 50 (Build script locked-file handling)

- Updated `build.ps1` to handle a stale locked `dist\\RadialDockInstaller.exe` more cleanly.
- The build script now:
  - attempts to stop a running `RadialDockInstaller.exe` before building
  - removes the previous installer EXE before PyInstaller runs
  - fails explicitly if the old EXE cannot be removed
  - checks `$LASTEXITCODE` after PyInstaller and only prints success if the new EXE actually exists
- This prevents the previous false-positive `Build complete` message after a failed build caused by a locked output file.

### 2026-03-01 - Change 51 (Shortcut-launch startup experience)

- Added a dedicated `--shortcut-launch` mode for desktop and Start Menu shortcut launches.
- Updated `src/radialdock/install.py` so desktop and Start Menu shortcuts include that flag, while the Windows startup shortcut does not.
- Updated `src/radialdock/app.py` to emit a startup-launch signal on that path after the UI is loaded.
- Updated `ui/Main.qml` so shortcut-launches:
  - open the radial menu centered on screen
  - optionally show a startup message card explaining:
    - what RadialDock is
    - the default shortcut (`Ctrl+Space`)
    - that the shortcut can be changed in Settings
- Added a persisted `startup_message_enabled` setting in `src/radialdock/model.py`.
- The startup message includes a `Turn Off Startup Message` toggle, and it never appears for normal hotkey launches.

### 2026-03-01 - Change 52 (Build script no-process guard)

- Replaced the `taskkill` call in `build.ps1` with a PowerShell-native process stop:
  - `Get-Process ... | Stop-Process -Force`
- This avoids the noisy `RadialDockInstaller.exe not found` error when no old installer process is running.
- Result: rebuilding is quiet in the normal case where no previous installer instance is active.

### 2026-03-01 - Change 53 (Startup card click fix + versioned builds)

- Fixed `ui/Main.qml` startup card hit-testing:
  - the startup card content column now renders above the card-wide mouse catcher
  - `Turn Off Startup Message` and `Continue` are now clickable
- Added `VERSION.txt` at repo root with default `0.0.0`.
- Updated `build.ps1` so every build now:
  - prompts for a version number (default is the saved value from `VERSION.txt`)
  - saves that version back to `VERSION.txt`
  - includes `VERSION.txt` in the PyInstaller bundle
  - outputs a versioned installer name: `RadialDockInstaller-<version>.exe`
- Added `appVersion` in `src/radialdock/model.py`, which reads the bundled/source `VERSION.txt`.
- Added version display to the Settings UI in `ui/Settings.qml`.

### 2026-03-01 - Change 54 (Startup help on any launch + empty fresh ring)

- Updated `src/radialdock/app.py` so the centered startup help now appears on any app launch while the startup message setting is enabled.
- If the user turns the startup message off, normal non-shortcut launches return to starting hidden, while shortcut launches still open centered.
- Removed the old placeholder default ring items in `src/radialdock/model.py`; fresh installs now start with an empty ring.
- Expanded the startup help text in `ui/Main.qml` to explain how to:
  - add items by dragging files/folders/shortcuts in from Explorer
  - remove items by dragging them out of the ring

### 2026-03-01 - Change 55 (Prefilled build version prompt + repeat startup help)

- Replaced the console `Read-Host` version prompt in `build.ps1` with a prefilled Windows input dialog.
- The dialog now opens with the last saved version already in the input field, so pressing Enter accepts it unchanged.
- Updated `ui/Main.qml` so the startup help appears on every radial-dock open while the startup message setting remains enabled.
- Result:
  - version iteration is faster during packaging
  - users keep seeing the onboarding help until they explicitly turn it off

### 2026-03-01 - Change 56 (Build version prompt moved back to terminal)

- Replaced the temporary GUI version dialog in `build.ps1` with a terminal prompt again.
- The build now prints the last saved version and accepts plain Enter to keep it unchanged.
- This keeps the build flow fully in the terminal while preserving the saved default-version behavior.

### 2026-03-01 - Change 57 (Async auto-refresh + startup warm-up)

- Updated `src/radialdock/model.py` so `refreshEnabledData()` no longer performs filesystem refresh work on the visible open path.
- The dock now:
  - opens immediately
  - runs icon/folder refresh in a background worker
  - applies stale-item removal and folder-cache updates on the main thread after the scan finishes
- Added a revision guard so background refresh results are skipped if settings changed while the refresh was running.
- Added `warmStartupCaches()` in `src/radialdock/model.py` to prefill current ring icon sources while the app is hidden.
- Updated `src/radialdock/app.py` to schedule that light warm-up shortly after startup.

### 2026-03-04 - Change 58 (Step-plan closure + version-based tracking)

- The original step-based development plan is now considered complete through Step 13.
- `docs/DEV_PLAN.md` is now treated as archived scope reference and should not be used for ongoing feature tracking.
- Ongoing work will now be tracked by app version and targeted journal entries instead of step numbers.
- Current documented version is now set to `0.9.4`.
- Future version bumps will be applied only when explicitly requested by the user.

### 2026-03-04 - Change 59 (Windows shortcut icon extraction fix)

- Updated `src/radialdock/model.py` so `.lnk` shortcut icons no longer rely only on Qt's generic `QFileIconProvider`.
- The shortcut icon flow now:
  - reads shortcut metadata (`IconLocation`, `TargetPath`) through Windows shell COM
  - extracts resource icons from `.exe`/`.dll`/`.icl`/`.cpl`/`.mun` icon locations when present
  - falls back to the shortcut target's real icon when available
  - falls back to Windows shell icon lookup for the `.lnk` itself
- This should make shortcut icons in both the main ring and folder views match Explorer much more reliably, including many shell-linked and game shortcut cases that previously showed generic placeholders.

### 2026-03-04 - Change 60 (`.url` shortcut icon support)

- Extended the Windows shortcut icon path in `src/radialdock/model.py` to cover `.url` files as well as `.lnk`.
- `.url` files are now treated as `shortcut` items for icon purposes.
- The `.url` icon flow now:
  - parses `IconFile` and `IconIndex` from the `InternetShortcut` section when present
  - uses that icon resource if available
  - otherwise falls back to the Windows shell icon for the `.url` file itself
- This should fix missing icon graphics for pinned `.url` items and `.url` shortcuts shown inside folder views.

### 2026-04-07 - Change 94 (Folder view now opens as a separate scene window)

- Added `DevPlans/folder_scene_transition_plan.md` and ignored `DevPlans/` in `.gitignore` so this transition plan is preserved locally without being tracked.
- Updated `ui/RadialRing.qml` so folder open state no longer changes `preferredStageWidth` / `preferredStageHeight`; the main dock window now stays at its normal size while a folder is open.
- Added explicit `folderSceneOpened` / `folderSceneClosed` signals in `ui/RadialRing.qml`.
- Updated `ui/Main.qml` to show the folder view in a separate frameless tool window centered on the main dock position.
- The main dock stage now fades out while the separate folder scene fades in, instead of resizing or morphing the main dock window.
- Returning from a folder now fades out the separate folder scene and then replays the normal main dock reveal animation.

### 2026-04-07 - Change 95 (Folder return now keeps the main dock hidden until the shared reveal starts)

- Replaced the old completed folder-scene plan in `DevPlans/` with `DevPlans/folder_return_reveal_plan.md`.
- Updated `ui/Main.qml` to decouple main dock scene visibility from `folderSceneVisible`.
- Added explicit `mainSceneVisible` state so the dock remains hidden while the folder scene fades out.
- The main dock scene is now only shown again through `playMainRingReveal()`, which aligns folder return with the same reveal path used by normal dock open.
- Disabled the stage opacity behavior during the active reveal so there is no extra fade layer on top of the shared dock opening animation.

### 2026-04-07 - Change 96 (Folder open now uses a decorative expanding backdrop again)

- Audited the old folder-open animation and confirmed the original expanding effect came from the main dock backdrop following folder-driven stage resizing.
- Reused that old backdrop styling and width/height easing in a new decorative transition layer instead of restoring the old geometry coupling.
- Updated `ui/Main.qml` to add a dedicated `folderBackdropWindow` that:
  - starts from the current dock backdrop footprint
  - expands toward the folder scene footprint
  - fades independently of the main dock and folder scene windows
- Coordinated the folder-open timing so the main dock scene fades out, the decorative backdrop expands, and the folder scene fades in on top.
- The main dock and folder scene remain mechanically separated, so this restores the visual expansion effect without reintroducing the old movement bug.

### 2026-04-07 - Change 97 (Folder backdrop now stays as a passive underlay beneath the instant folder scene)

- Replaced the fragile folder-open backdrop timing with a narrower implementation in `ui/Main.qml`.
- The folder scene now stays on the last known-good immediate show path.
- Added a separate passive `folderBackdropWindow` that:
  - starts from the dock backdrop footprint
  - animates toward the actual clamped folder scene geometry
  - remains visible underneath the folder scene while the folder is open
- The decorative underlay no longer delays, gates, or owns any folder content.
- Folder close/back now hides that passive underlay again without changing the stable folder return path.

### 2026-04-07 - Change 98 (Folder backdrop expansion now reliably replays when reopening the same folder)

- Updated `ui/Main.qml` so the passive folder backdrop snaps back to the dock footprint before each new folder-open expansion.
- Added explicit `folderBackdropSnapGeometry` state to temporarily disable geometry behaviors while resetting the backdrop start state.
- This avoids the previous case where reopening the same folder could skip the visible expansion because the backdrop never got a clean snapped starting geometry before animating again.

### 2026-04-07 - Change 99 (Folder backdrop target expansion now waits one frame before animating)

- Updated `ui/Main.qml` so the passive folder backdrop no longer applies its target geometry in the same event cycle it becomes visible.
- Added `folderBackdropKickoffDelay` and changed the expansion kickoff timer to wait one frame before animating toward the folder scene geometry.
- This gives the snapped dock-sized start state a real rendered frame, which should let the expansion replay consistently across repeated folder opens in the same session.

### 2026-04-07 - Change 100 (Folder backdrop expansion now uses an explicit restartable animation)

- Replaced the passive folder backdrop's geometry `Behavior` path in `ui/Main.qml` with an explicit `ParallelAnimation`.
- The backdrop now restarts its `x`, `y`, `width`, and `height` expansion animation directly on each folder open, instead of relying on implicit behavior changes.
- Added `folderBackdropExpanding` state so folder-scene resize updates do not fight the backdrop while that explicit animation is active.
- This should make the expansion deterministic across repeated folder opens in the same session.
