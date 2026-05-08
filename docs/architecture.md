# Architecture

This document describes how the Python backend, QML UI, and global hotkey fit together. Code references point at the current implementation in [`app.py`](../src/radialdock/app.py), [`model.py`](../src/radialdock/model.py), [`win_hotkey.py`](../src/radialdock/win_hotkey.py), and [`Main.qml`](../ui/Main.qml) / [`RadialRing.qml`](../ui/RadialRing.qml).

---

## Process bootstrap

1. [`main()`](../src/radialdock/app.py) parses CLI flags, optionally runs install/uninstall, then starts a normal run: **`QApplication`**, **`AppPaths`**, **`AppModel`**, **`GlobalHotkeyManager`**, **`OverlayController`**, **`QQmlApplicationEngine`**.

2. The engine registers two root context properties (same names QML uses globally):
   - **`appModel`** → [`AppModel`](../src/radialdock/model.py) instance  
   - **`backend`** → [`OverlayController`](../src/radialdock/app.py) instance  

3. The engine adds the repo’s [`ui/`](../ui/) directory as a QML import path and loads [`Main.qml`](../ui/Main.qml). If the root object list is empty, startup fails (e.g. QML error).

4. **Hotkey wiring (after QML loads):**  
   `GlobalHotkeyManager.activated` is connected to `OverlayController.on_hotkey`. The string in persisted settings is parsed and registered with Windows (`RegisterHotKey` for keyboard shortcuts, or a low-level mouse hook for mouse-button shortcuts). See [Hotkey → overlay](#hotkey-to-overlay) below.

---

## Python: `AppModel`

[`AppModel`](../src/radialdock/model.py) is a **`QObject`** that owns **application data and behavior** exposed to QML:

- **Settings** loaded from / saved to JSON under [`AppPaths.config_file`](../src/radialdock/model.py) (location depends on portable vs installed vs source run).
- **Qt properties** (`Property(…)`) for values the UI reads and writes: hotkey string, toggles, animation speed, folder thresholds, etc.
- **`@Slot` methods** for imperative actions: open paths, folder listing, icon URLs, save/import ring items, etc.
- **Signals** for async or pushed updates: e.g. `ringItemsChanged`, `folderEntriesReady(folderPath, entries)`, `folderRefreshStateChanged`, `previewVersionChanged`.

Ring tiles and folder caches are represented in Python (`DockItem`, nested groups, `folder_cache`). QML does **not** parse `config.json` itself; it goes through `AppModel`.

---

## Python: `OverlayController`

[`OverlayController`](../src/radialdock/app.py) is a thin **`QObject`** focused on **shell/UI orchestration** that is not purely “model data”:

- Holds references to **`AppModel`**, **`GlobalHotkeyManager`**, and original **launch arguments** (for restart, startup shortcut, install helpers).
- **Hotkey application from settings:** `AppModel.hotkeyChanged` is connected to `_apply_model_hotkey`, which re-registers the global shortcut (with suppression when `trySetHotkey` updates the model to avoid a loop).
- **Slots** called from QML on `backend`: e.g. `requestHide`, `trySetHotkey`, `quitApp`, `restartApp`, import/export settings, launch-on-startup toggles, `resetAllQuickSettings` (delegates to the model).
- **Signals** the QML window listens to: `hotkeyTriggered(x, y)`, `hideRequested`, `shortcutLaunchRequested`, `hotkeyApplyResult`, `settingsTransferResult`, `launchOnStartupChanged`.

`OverlayController` does **not** replace `AppModel` for settings storage; it delegates persistence and ring data to `AppModel` where needed.

---

## QML: `Main.qml`

[`Main.qml`](../ui/Main.qml) defines a **frameless, transparent, topmost `Window`** that is the **radial overlay shell**:

- **Visibility and animation** of show/hide (`openAnim` / `closeAnim`), cursor-based positioning (`showAtCursor`, `toggleAtCursor`), and optional folder **sub-windows** (`folderSceneWindow`, `folderBackdropWindow`) for full-screen folder view vs the main ring stage.
- **Binds to `appModel`** for presentation policy: e.g. `animationSpeedScale`, `animationsEnabled`, `startupMessageEnabled` (and related behavior).
- **Subscribes to `backend`** via a `Connections` target:
  - `onHotkeyTriggered(x, y)` → `toggleAtCursor(x, y)` (open near cursor or hide if already visible).
  - `onHideRequested` → `hideOverlay()`.
  - `onShortcutLaunchRequested` → startup / centered reveal path when launched from a shortcut with messaging enabled.

The **main ring UI** is an instance of **`RadialRing`** (`id: ringWidget`) centered in a `stage` item. Folder view uses **`FolderView`** fed from `ringWidget` folder properties when `RadialRing` opens a folder path.

---

## QML: `RadialRing.qml`

[`RadialRing.qml`](../ui/RadialRing.qml) implements the **dock interaction layer**:

- **Local state:** ring item model (`ListModel` / repeater), drag–drop, group overlay, folder-open state, settings panel open state, signals `folderBackRequested` / `settingsBackRequested` consumed by `Main.qml`.
- **`loadFromSettings()` / `serializeItems()`:** pulls ring structure from **`appModel`** (JSON-ish ring items) and persists via **`appModel.saveRingItems`** when the user edits the ring.
- **`Connections` to `appModel`:** reacts to `ringItemsChanged`, `folderEntriesReady`, `folderRefreshStateChanged`, etc., to refresh tiles and folder listings.
- Embeds the **`Settings`** component ([`Settings.qml`](../ui/Settings.qml)) for the in-app settings UI; that UI reads/writes **`appModel`** properties and calls **`backend`** where appropriate (hotkey, export, quit).

---

## Data flow: Python → QML

| Mechanism | Use |
|-----------|-----|
| **`engine.rootContext().setContextProperty("appModel", model)`** | Any QML file can read **`appModel.someProperty`** and invoke **`appModel.someSlot(...)`** if exposed on `AppModel`. |
| **`Property` + `notify` signal** | When Python updates a property, QML bindings and `Connections` to `on<Property>Changed` handlers update the UI. |
| **Explicit signals** (`Signal(...)`) | e.g. `folderEntriesReady` → `Connections { target: appModel; function onFolderEntriesReady(...) { ... } }` in `RadialRing.qml`. |
| **`backend` context property** | Same pattern for `OverlayController` signals and slots (`requestHide`, `trySetHotkey`, …). |

Flow from model to scene graph is **Qt’s meta-object / binding system**; there is no custom IPC.

### QML → Python

- Property assignments in QML call the **`setter`** on `AppModel` when defined (e.g. `appModel.folderCompactThreshold = value`).
- Button handlers and `Connections` call **`@Slot`** methods on `appModel` or `backend`.

---

## Hotkey → overlay

End-to-end path:

1. **`GlobalHotkeyManager`** ([`win_hotkey.py`](../src/radialdock/win_hotkey.py)) installs a **native event filter** on the `QApplication`. For **keyboard** shortcuts it calls **`RegisterHotKey`**. For **mouse** shortcuts it installs a **low-level mouse hook** (`WH_MOUSE_LL`). When the OS delivers the hotkey (or matching mouse message), the manager emits **`activated`**.

2. In [`main()`](../src/radialdock/app.py), **`hotkey.activated.connect(controller.on_hotkey)`**.

3. **`OverlayController.on_hotkey`** reads **`QCursor.pos()`** and emits **`hotkeyTriggered(int x, int y)`**.

4. **`Main.qml`** `Connections` on **`backend`**: **`onHotkeyTriggered(x, y)`** calls **`toggleAtCursor(x, y)`**, which positions the window and runs show/hide animations.

Changing the shortcut from Settings goes through **`backend.trySetHotkey(string)`**, which validates, registers with **`GlobalHotkeyManager`**, and updates **`AppModel.hotkey`** so the value persists.

---

## Related files

| Area | File |
|------|------|
| Entry point / wiring | [`src/radialdock/app.py`](../src/radialdock/app.py) |
| Data + QML API surface | [`src/radialdock/model.py`](../src/radialdock/model.py) |
| Global hotkey | [`src/radialdock/win_hotkey.py`](../src/radialdock/win_hotkey.py) |
| Overlay shell | [`ui/Main.qml`](../ui/Main.qml) |
| Ring + settings panel host | [`ui/RadialRing.qml`](../ui/RadialRing.qml) |
| Settings form | [`ui/Settings.qml`](../ui/Settings.qml) |
| Dev launcher (watch + restart) | [`dev.bat`](../dev.bat) / [`dev.ps1`](../dev.ps1) → [`scripts/dev_watch.py`](../scripts/dev_watch.py) |

For day-to-day development entry points, see [dev-workflow.md](dev-workflow.md).
