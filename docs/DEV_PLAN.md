# RadialDock Development Plan

## Purpose

This file is the single source of truth for project planning and milestone tracking.

## Current Position

- Date: 2026-02-28
- Active phase: MVP buildout
- Current step: **Step 12**
- Completed: **Step 1, Step 2, Step 3, Step 4, Step 5, Step 6, Step 7, Step 8, Step 9, Step 10, Step 11**
- In progress: **Step 12**

## Status Legend

- `DONE`: Implemented and validated.
- `IN PROGRESS`: Under active implementation.
- `TODO`: Not started.
- `BLOCKED`: Waiting on decision/dependency.

## Milestone Board (MVP Steps 1-13)

| Step | Name | Status | Exit Criteria |
|---|---|---|---|
| 1 | Repo + venv + deps + hello overlay | DONE | `.venv` exists, deps installed, QML overlay launches. |
| 2 | Global hotkey + cursor-centered overlay | DONE | `Ctrl+Space` toggles overlay at cursor via `RegisterHotKey/WM_HOTKEY`. |
| 3 | Radial ring layout + smooth open/close | DONE | Ring layout finalized with polished animation states and sample data. |
| 4 | Internal drag reorder + drag-out remove | DONE | Dragging reorders with animated neighbor shifts; drag outside removes with subtle animation. |
| 5 | External Explorer drop into ring | DONE | Files/folders/shortcuts dropped from Explorer are added to ring items. |
| 6 | Persistence for ring items | DONE | Items saved/loaded from `%AppData%\\RadialDock\\config.json`. |
| 7 | Per-item icons | DONE | Ring items show file/folder/app icons from Windows/Qt icon provider. |
| 8 | Folder open sub-view + open file | DONE | Clicking folder opens inner folder view tiles; clicking tile opens item. |
| 9 | Thumbnail cache (SQLite + disk) | DONE | Thumbnails generated/cached by path + mtime; cache hit path works. |
| 10 | Center settings menu + runtime preferences | DONE | Center click opens settings panel with confirmation actions and persisted runtime controls. |
| 11 | Automatic refresh controls | DONE | Separate main-item and folder refresh toggles drive scan behavior; disabled checks do not touch disk; manual refresh respects enabled toggles. |
| 12 | Self install/uninstall via same EXE | IN PROGRESS | `--install`, `--uninstall`, installed marker, copy to `%LocalAppData%\\RadialDock`, Start Menu shortcut. |
| 13 | PyInstaller onefile + smoke test | TODO | `dist\\RadialDock.exe` produced; smoke test covers launch/hotkey/basic open. |

## Detailed Work Plan

### Step 3 - Radial Ring Layout and Motion

- Finalize ring geometry and spacing for 6-16 items.
- Add smooth open/close scale + opacity transitions.
- Ensure focus/escape/click-outside behavior remains stable.
- Verify high-DPI scaling and multi-monitor cursor positioning.

### Step 4 - Internal Drag Reorder and Remove

- Add drag handles and reorder index calculation in QML.
- Animate sibling shifts during drag hover.
- Add drag-out threshold zone for removal and removal animation.
- Ensure model order updates atomically.

### Step 5 - External Drag and Drop

- Attempt QML `DropArea` for URLs first.
- If Explorer drag is inconsistent, implement Python-level drop event handling and forward paths to model/QML.
- Normalize dropped path types: file, folder, shortcut.

### Step 6 - Persistence

- Extend model schema for ring entries (path, label, kind, icon key, order).
- Save on mutation with debounce.
- Load config on startup with corrupted-file fallback.

### Step 7 - Icons

- Add icon resolution service (Qt/Windows shell icon extraction).
- Cache icon file references in memory + on disk.
- Provide fallback icon for missing/unresolvable items.

### Step 8 - Folder View

- Build inner panel/ring folder content view.
- Show tiles with icon/thumbnail and hover magnify.
- Click tile to open via `os.startfile`.

### Step 9 - Thumbnail Cache

- Create SQLite schema for metadata and disk path references.
- Generate thumbnails via Pillow (bounded size, consistent format).
- Key cache by normalized path + last modified timestamp.

### Step 10 - Settings Hub (new)

- Add center-click settings access in radial core.
- Add persisted quick settings in user config (not source files).
- Include clear-all and reset-defaults with confirmations.
- Add runtime controls for animation speed, animation disable, and compact list threshold.

### Step 11 - Automatic Refresh Controls

- Add separate toggles for:
  - main ring item existence checks
  - folder content refresh
- On overlay open, run only the enabled checks.
- When folder refresh is disabled, serve cached folder listings only and avoid touching disk.
- Add a manual refresh action that runs only currently enabled checks.
- Optional `watchdog` file watching remains deferred.

### Step 12 - Install/Uninstall

- Install copies EXE to `%LocalAppData%\\RadialDock`.
- Create Start Menu shortcut.
- Write installed marker and support both interactive and CLI flows.
- Uninstall removes shortcut, marker, and installed files safely.

### Step 13 - Packaging and Smoke Test

- Finalize `build.ps1` and PyInstaller data inclusion.
- Produce onefile EXE and run smoke tests:
  - app launch
  - hotkey toggle
  - add/open basic item
  - close behavior
- Document build and troubleshooting notes.

## Cross-Cutting Quality Gates

- All Python modules compile.
- No uncaught exceptions during normal startup/close.
- Journal updated after meaningful changes.
- README remains runnable for first-time setup.
- After each completed step, provide a simple test checklist for user verification before moving on.

## Step Verification Protocol

- When a step is marked `DONE`, include plain-language test instructions in the handoff.
- Test instructions should be short, click-by-click where possible, and include expected result text.
- If a step cannot be fully tested locally (for example GUI-only/manual flow), call that out clearly.

## Latest Verification Checklist

### Step 11 (Automatic refresh controls)

1. Launch app with `python -m radialdock.app`.
2. Press `Ctrl+Space`.
3. Click the center core to open settings.
4. Leave `Automatic icon refresh` on, delete one file linked in the ring, then open the menu again.
5. Confirm the missing ring item is removed automatically.
6. Turn `Automatic folder refresh` off, open a folder once, then change that folder in Explorer.
7. Reopen the same folder and confirm it still shows the cached listing instead of rescanning.
8. Click `Manual Refresh` and confirm only the currently enabled checks run.

## Risk Register

- Explorer drop interoperability in pure QML may be inconsistent on Windows.
- Global hotkey conflicts can block registration.
- Thumbnail generation performance for large folders may require throttling.
- Onefile startup latency may impact perceived responsiveness.

## Decision Log

- 2026-02-27: Use PySide6 + QML for UI and ctypes-based hotkey handling around Qt native event filter.
- 2026-02-27: Keep user config in `%AppData%\\RadialDock\\config.json` and cache in app data cache folder.
- 2026-02-27: Adopt universal right-click back behavior (folder view back, then overlay close).
- 2026-02-27: Use compact folder list fallback when folder entry count exceeds 50 (threshold kept easy to edit in QML for now).
- 2026-02-27: Runtime quick settings are persisted in user config (`config.json`) so source files remain unchanged.
- 2026-02-28: Split refresh behavior into separate user-controlled icon and folder toggles; when a refresh type is disabled, the app avoids corresponding existence scans and uses cached folder listings only.
