# Development workflow

This page describes how the dev launcher and file watcher work. For clone, venv, and `pip install`, see [Run From Source While Developing](../README.md#run-from-source-while-developing) in the README.

---

## Entry points

### `dev.bat` (double-click)

- **Role:** `cd` to the repo root, then run PowerShell on `dev.ps1` with **all** arguments forwarded (`%*`).
- **Typical use:** Double-click in Explorer when you do not already have a terminal open.
- **Exact behavior:** If the child PowerShell process exits with a **non-zero** code, the batch file runs `pause` so the window stays open and you can read the error.
- **Note:** Arguments are passed through; see [Passing arguments](#passing-arguments-to-the-app) below.

### `dev.ps1` (PowerShell)

- **Role:** Resolve Python, run the [single-instance guard](#single-instance-guard-and--force) if not forced, then start `scripts/dev_watch.py`.
- **Python used (in order):**  
  1. `.venv\Scripts\python.exe` if it exists under the repo root  
  2. Otherwise `python` on `PATH` (warning printed)
- **Does not** start `radialdock.app` itself except by invoking `dev_watch.py`.

### `scripts/dev_watch.py`

- **Role:** Watch **`src/radialdock/`** and **`ui/`** recursively; on relevant file changes, **terminate** the running app process and **start a new** `python -m radialdock.app` subprocess.
- **Watched extensions:** `.py`, `.qml` (see `_SUFFIXES` in `dev_watch.py`). Editor temp files (`*.tmp`, swap files, `__pycache__`, etc.) are ignored so saves do not spam restarts.
- **Working directory for the app:** repo root.
- **Stop the watcher:** focus the console where it is running and press **Ctrl+C** (triggers shutdown: cancel debounce timer, stop observer, terminate child app).

---

## Auto-restart (not hot reload)

Qt Quick does **not** reliably apply QML edits to an already-running scene from Python. The supported workflow is **process restart**: each change eventually kills the old `radialdock.app` process and spawns a new one.

Flow:

1. **First start:** `dev_watch` starts one child: `python -m radialdock.app …` with `RADIALDOCK_DEV=1` (see below).
2. **Change under `src/radialdock` or `ui`:** watchdog fires → debounce timer (default **0.35 s** after the last event) → `Runner.stop()` then `Runner.start()`.

**`--debounce`:** Only affects watcher-side timing (must come **before** `--`):

```text
python scripts/dev_watch.py --debounce 0.5
python scripts/dev_watch.py --debounce 0.5 -- --portable
```

If QML “does not update,” confirm the file is under `ui/` and saved; wait at least the debounce interval. If you run `python -m radialdock.app` **without** the watcher, nothing restarts until you run the app again manually.

---

## `RADIALDOCK_DEV`

Only the **child** app process gets `RADIALDOCK_DEV=1` in its environment (set in `Runner.start()` inside `dev_watch.py`). The watcher process itself does not need it.

**Effect:** The app **skips the first-run install/manage prompt** so automated restarts are not blocked by that dialog. Hotkeys, settings paths, and persistence are unchanged.

**Contrast:** `python -m radialdock.app` from a shell does **not** set `RADIALDOCK_DEV` unless you export it yourself—behavior matches a normal manual source run (prompt may appear when applicable).

---

## Single-instance guard and `-Force`

**Purpose:** Avoid starting a **second** `dev_watch.py` for the **same** repo checkout (same normalized absolute path to `scripts\dev_watch.py`).

**Mechanism (`dev.ps1`):** Query `Win32_Process` for `python.exe` / `python3.exe` / `py.exe`; normalize each process `CommandLine` (lower case, `/` → `\`); if any command line **contains** the normalized full path of this checkout’s `dev_watch.py`, treat as duplicate.

**If duplicate (and `-Force` not used):** Print a yellow message listing matching PIDs, **exit 0** (success—no second watcher).

**`-Force`:** Skip the guard entirely and always launch `dev_watch.py`. Use when you intentionally want two watchers (e.g. two terminals) on the same tree.

```powershell
.\dev.ps1 -Force
.\dev.bat -Force
```

`-Force` is a **PowerShell** switch on `dev.ps1`; it is **never** forwarded to Python.

---

## Passing arguments to the app

Arguments meant for `radialdock.app` go **after** a lone `--` so `dev_watch` does not parse them as its own flags.

```powershell
.\dev.ps1 -- --portable
.\dev.ps1 -Force -- --portable
python scripts/dev_watch.py -- --portable
python scripts/dev_watch.py --debounce 0.5 -- --portable
```

Order: optional `dev.ps1 -Force`, then `--`, then app args.

---

## Common issues

| Symptom | Things to check |
|--------|-------------------|
| **Hotkey does nothing** | Another app may own **Ctrl+Space** (IDE, game, IME). Change the shortcut in RadialDock **Settings**, or exit the conflicting app. Ensure RadialDock actually started (tray / task manager). Run elevated only if your environment requires it for global hooks (unusual). |
| **“Dev watcher already running…”** | Expected if you started `dev.bat` twice for the same clone. Either use the existing watcher window or start again with **`-Force`**. Exit code **0** is intentional. |
| **Second watcher when using another clone** | The guard keys off the **absolute path** to `dev_watch.py`. Different directories → both can run. |
| **`No .venv at … using python on PATH`** | Create `.venv` and install deps per README, or ensure `python` on PATH has PySide6 and the editable install. |
| **QML changes never appear** | Confirm you are running under **`dev_watch`**, file is under **`ui/`**, and you waited past **debounce**. Remember: restart-based, not live hot reload. |
| **`pause` after dev.bat** | Non-zero exit from PowerShell—often missing deps, wrong cwd, or script error. Read the message above `pause`. |
| **Portable / settings location** | `--portable` changes where config lives; useful for isolated testing. Combine with the `--` forwarding rules above. |

---

## Quick command reference

```text
dev.bat
dev.bat -Force
dev.bat -- --portable

.\dev.ps1
.\dev.ps1 -Force
.\dev.ps1 -- --portable

python scripts/dev_watch.py
python scripts/dev_watch.py --debounce 0.5 -- --portable
```

Stop watcher: **Ctrl+C** in the window running `dev_watch`.
