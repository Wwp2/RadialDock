# Cursor guidance for RadialDock

Facts below match the current codebase; unknowns are labeled **Unknown**.

## What this repo is

Windows radial launcher: **PySide6 + Qt Quick**. Entry: `src/radialdock/app.py` (`main()`). UI is **QML only** (`ui/*.qml`), loaded with `QQmlApplicationEngine`. Context properties: **`backend`** (`OverlayController`), **`appModel`** (`AppModel`).

| File | Role |
|------|------|
| `ui/Main.qml` | Frameless, always-on-top, transparent overlay window; wires `backend` signals to show/hide/toggle |
| `ui/RadialRing.qml` | Radial layout, item views, drag/drop, reorder animations — **large, high churn** |
| `src/radialdock/model.py` | `AppModel`, `DockItem`, `Settings`, persistence, `openPath`, icons/thumbnails |
| `src/radialdock/win_hotkey.py` | Win32 global hotkey (`RegisterHotKey`, `WM_HOTKEY`) + native event filter |
| `src/radialdock/cache.py` | Thumbnail SQLite cache |
| `src/radialdock/shell_open.py` | Shell open helper |
| `src/radialdock/install.py` | Install/startup/shortcuts |

## Tech stack

- **UI**: PySide6 `>=6.8,<7`, Qt Quick.
- **Python**: `requires-python >=3.11` in `pyproject.toml`; **`build.ps1` requires 3.13.x** for the venv used to build the installer.
- **Packaging**: PyInstaller via `build.ps1`; locked deps: `requirements-lock.txt`.
- **CI**: **Unknown** — `.github/` is gitignored here; no workflows verified in-tree.

## Data flow

1. **`AppModel`** holds canonical ring data as Python structures (`DockItem`, nested `children` for groups) and exposes **`ringItems`** to QML as a property (notify: `ringItemsChanged`).
2. **`RadialRing.qml`** defines a QML **`ListModel`** (id `ringItems`) populated from **`appModel.ringItems`** on load/sync.
3. User edits (drag reorder, drop from Explorer, remove, group merge) mutate the **local `ListModel`**, then **`serializeItems()`** builds the payload and calls **`appModel.saveRingItems(...)`** (debounced in QML).
4. **`AppModel.saveRingItems`** updates Python state and persists **`config.json`** (and emits `ringItemsChanged` — the journal documents a **`skipNextModelSync`** guard in `RadialRing.qml` to avoid double-apply on self-originated saves).

**Persistence file**: For the usual source run, **`%AppData%\RadialDock\config.json`**. Portable (`--portable`) uses `.radialdock` under cwd; installed frozen exe under `%LocalAppData%\RadialDock\` when the exe lives there — see **`AppPaths`** in `model.py`.

**Launch actions**: Item activation goes through **`appModel.openPath(path)`** (slot on `AppModel`).

## Input flow

| Layer | Mechanism |
|-------|-----------|
| **Global** | `GlobalHotkeyManager` (`win_hotkey.py`) → `OverlayController.on_hotkey` → signal **`hotkeyTriggered(x, y)`** |
| **Into UI** | `Main.qml` **`Connections`** on **`backend`**: `onHotkeyTriggered` → **`overlay.toggleAtCursor(x, y)`** (also `onShortcutLaunchRequested`, `onHideRequested`) |
| **Overlay** | QML only: **`MouseArea`**, **`Shortcut`** (e.g. Esc), **`DropArea`**, ring-local handlers in **`RadialRing.qml`** |

Win32 path does not replace in-overlay input; it **opens/toggles** the window; interaction stays in QML.

## Where to implement changes

| Change type | Place |
|-------------|--------|
| Visual layout, animation, gestures, **DropArea** / drag thresholds | **`ui/*.qml`** (often **`RadialRing.qml`** or **`Main.qml`**) |
| Ring/item **truth**, settings fields, JSON load/save, **`openPath`**, icons, folder listing, threads | **`AppModel` / `model.py`** |
| Global hotkey strings, overlay hide/restart, import/export backup, startup shortcut | **`OverlayController` / `app.py`** + **`install.py`** as needed |
| OS/shell/COM | **Python** (`model.py`, `shell_open.py`, `install.py`) — not QML |

## Warnings

- **`RadialRing.qml`**: Central to drag/drop, reorder, group logic, and **`saveRingItems`** timing. Small edits can break animation sync or the **`ringItemsChanged`** ↔ ListModel reload dance.
- **QML ↔ Python bindings**: Renaming context properties (`backend`, `appModel`), **`Property`/`Slot` names**, or **`ringItems`** shape breaks startup or silent failures — verify **`engine.rootObjects()`** path in `app.py` after changes.
- **`win_hotkey.py`**: Treat as fragile; test toggle and edge shortcuts after edits.
- **`DockItem` / JSON**: Changing keys or nesting without migration breaks existing user **`config.json`** and backup files.

## Build and run

```bash
python -m pip install -r requirements.txt
python -m pip install -e .
python -m radialdock.app
```

Live reload / dev watcher (`dev_watch`, `RADIALDOCK_DEV`): see **README → Run The App From Source → Live reload while editing** (canonical).

Installer: `.\build.ps1` (requires `assets/`, `ui/`, `VERSION.txt`). Portable: `--portable`.

**Tests**: **Unknown** — no `pytest`/`unittest` usage found under `src/`; validate manually.

## PR expectations

- Small diffs; state config/portable/installed impact if touching **`AppPaths`** or JSON schema.
- List commands run, or say what was not run.

---

*Re-verify after major structural changes.*
