from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

APP_DIR_NAME = "RadialDock"
INSTALL_MARKER = "installed.marker"


def install_root() -> Path:
    local_app_data = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local")))
    return local_app_data / APP_DIR_NAME


def marker_path() -> Path:
    return install_root() / INSTALL_MARKER


def is_installed() -> bool:
    return marker_path().exists()


def install_self() -> int:
    target_dir = install_root()
    target_dir.mkdir(parents=True, exist_ok=True)
    exe_path = Path(sys.executable)
    if exe_path.suffix.lower() == ".exe":
        shutil.copy2(exe_path, target_dir / exe_path.name)
    marker_path().write_text("installed\n", encoding="utf-8")
    print(f"Installed marker written to {marker_path()}")
    print("Shortcut creation will be added in Step 11.")
    return 0


def uninstall_self() -> int:
    if not is_installed():
        print("Not installed.")
        return 0
    root = install_root()
    try:
        if root.exists():
            shutil.rmtree(root)
        print(f"Removed install directory: {root}")
    except OSError as exc:
        print(f"Uninstall failed: {exc}", file=sys.stderr)
        return 1
    return 0


def maybe_offer_install_or_uninstall(args: argparse.Namespace) -> int | None:
    if args.install:
        return install_self()
    if args.uninstall:
        return uninstall_self()
    return None
