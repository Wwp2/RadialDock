# AI change checklist (before accepting edits)

Quick pass for RadialDock AI-assisted edits.

## General
- [ ] **Scope is limited** — Maps to the task; no unrelated files or drive-by reformatting.
- [ ] **No unnecessary dependencies** — Justified and reflected in `requirements.txt` / `pyproject.toml` (and lockfile flow if installers are affected).
- [ ] **Build/run** — `python -m radialdock.app` and/or `.\build.ps1` when relevant, **or** explicitly noted as not run (no in-repo automated suite).

## Python ↔ QML
- [ ] **Responsibilities not mixed incorrectly** — Business rules and durable state stay in **`AppModel`** / Python; QML stays presentation + interaction (no duplicated launch/path rules that belong in Python).
- [ ] **`AppModel` remains single source of truth** — QML `ListModel` is a mirror; saves go through **`appModel.saveRingItems(...)`**, not ad-hoc JSON from QML.

## Data and serialization
- [ ] **`ringItems` / `DockItem` serialization intact** — No renamed or dropped JSON keys without migration; **`config.json`** compatibility preserved unless intentional.
- [ ] **`openPath` behavior** unchanged unless the task requires it (launch semantics live on **`AppModel.openPath`**).

## Input and overlay
- [ ] **Hotkey handling not broken** — `win_hotkey.py` / registration and **`backend.hotkeyTriggered`** → **`Main.qml`** toggle path still work.
- [ ] **Overlay show/hide** — `toggleAtCursor` / `hideOverlay` / `Connections` on **`backend`** still coherent.

## Interaction regressions
- [ ] **Drag/drop** (external + internal) still works.
- [ ] **Item reorder** and remove paths still line up with **`saveRingItems`** (watch for **`ringItemsChanged`** / **`skipNextModelSync`**-style issues in **`RadialRing.qml`**).

## Platform
- [ ] **Windows / shell** — If touching COM or shell APIs, behavior on target OS versions called out or **Unknown** acknowledged.
