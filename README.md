# RadialDock

## Project overview

**RadialDock** is a Windows launcher that shows a **radial menu** near the cursor. You pin files, folders, apps, and shortcuts on the ring, open nested folders and groups, and adjust behavior from an in-app settings panel.

**Tech stack:** **Python** application using **PySide6** (Qt 6) with the **Qt Quick** UI written in **QML** (`ui/`). Windows-specific pieces use the Win32 API and shell COM where needed (`pywin32`).

---

## Quick start (developers)

1. **Clone** this repository.

2. **Create a virtualenv and install the package in editable mode** (from the repo root):

   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   python -m pip install -r requirements.txt
   python -m pip install -e .
   ```

3. **Run the dev watcher** (recommended while changing Python or QML):

   - **Double-click** [`dev.bat`](dev.bat) in the repo root, **or**
   - In PowerShell: `.\dev.ps1`, **or**
   - `python scripts/dev_watch.py`

   [`dev.bat`](dev.bat) forwards all arguments to [`dev.ps1`](dev.ps1).

4. **Open the dock:** press **`Ctrl+Space`** (default global shortcut).  
   **Right-click** is the universal **Back** action inside the overlay.

---

## Development workflow

### Auto-restart (not hot reload)

[`scripts/dev_watch.py`](scripts/dev_watch.py) watches `src/radialdock/` and `ui/` for `.py` / `.qm` / `.qml` changes and **restarts** `python -m radialdock.app`. Qt Quick does not reliably hot-reload the running scene; process restart is the supported workflow.

Optional **`--debounce`** (seconds after the last save before restart) and arguments after **`--`** are forwarded to the app (e.g. `python scripts/dev_watch.py -- --portable`).

### `RADIALDOCK_DEV`

The watcher sets **`RADIALDOCK_DEV=1`** only on the **child** app process. That **skips the first-run install/manage prompt** so dev restarts are not blocked. It does **not** change hotkeys, settings file location, or persistence. Running `python -m radialdock.app` directly does **not** set this variable.

### Single-instance guard

[`dev.ps1`](dev.ps1) avoids starting a **second** watcher for the **same checkout** if `scripts/dev_watch.py` is already running (matched by normalized absolute path). If that happens, it prints a short message and exits successfully.

Use **`-Force`** to start another watcher anyway (e.g. two terminals):

```powershell
.\dev.ps1 -Force
.\dev.bat -Force
```

Forward app args separately, e.g. `.\dev.ps1 -Force -- --portable`. **`-Force`** is not passed to Python.

---

## Project structure

| Path | Role |
|------|------|
| [`src/radialdock/`](src/radialdock/) | Application code: entrypoint, model, hotkey, install helpers, cache, shell integration |
| [`ui/`](ui/) | Qt Quick (QML) UI |
| [`scripts/`](scripts/) | Development tools (e.g. [`dev_watch.py`](scripts/dev_watch.py)) |
| [`docs/`](docs/) | Extra documentation (journals, editor notes, checklists) |

---

## Build / install (short)

**Installer build (Windows):**

```powershell
.\build.ps1
```

Expects **Python 3.13.x** in `.venv`, installs from **`requirements-lock.txt`**, reads **`VERSION.txt`**, and writes **`dist\RadialDockInstaller-<version>.exe`** plus a build info JSON. See script output if the venv Python version is wrong.

**Rebuild and reinstall the packaged app locally** (Git Bash / shell with `bash`):

```bash
./rebuild_reinstall.sh
```

Runs `build.ps1`, then silent uninstall/install of the matching installer.

Day-to-day **source development** does not require these unless you are testing the installer.

---

## Notes

- **Windows focus:** The product targets **Windows** (global hotkey, shell shortcuts, Known Folders). Other platforms are out of scope.
- **Qt Quick UI:** Layout and interaction live in QML; logic and OS integration live in Python.
- **Python versions:** **`pyproject.toml`** requires **Python ≥ 3.11** for a normal editable install. **`build.ps1`** currently requires **3.13.x** for installer builds.
- **Hotkey:** The default **`Ctrl+Space`** may conflict with other apps (IDEs, games). Users can change the shortcut in **Settings** if needed.
- **Dependencies:** Runtime deps are listed in **`requirements.txt`**. Reproducible installer builds use **`requirements-lock.txt`**.

---

## License

See [`LICENSE`](LICENSE).
