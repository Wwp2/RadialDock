"""
Restart RadialDock when Python or QML sources change (development helper).

Normally started via ``dev.ps1`` / ``dev.bat`` at the repo root; ``dev.ps1`` avoids
launching a second watcher for the same checkout unless ``-Force`` is used.
See ``docs/dev-workflow.md``.

Qt Quick does not hot-reload the running scene graph reliably from Python;
restarting the process is the practical way to get near-instant feedback.

Usage (from repo root, venv activated):

  python scripts/dev_watch.py
  python scripts/dev_watch.py -- --portable
  python scripts/dev_watch.py --debounce 0.5 -- --portable

Arguments after a lone "--" are forwarded to radialdock.app (e.g. --portable).
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

_REPO_ROOT = Path(__file__).resolve().parents[1]
_SRC = _REPO_ROOT / "src" / "radialdock"
_UI = _REPO_ROOT / "ui"

_SUFFIXES = (".py", ".qml")


def _is_ignored_artifact(path: str) -> bool:
    """Filter editor temp/swap files — developer-side only; avoids spurious restarts."""
    lower = path.replace("\\", "/").lower()
    if "__pycache__" in lower:
        return True
    name = Path(path).name.lower()
    if name.startswith(".#"):
        return True
    if name.endswith("~"):
        return True
    if name.startswith("~$"):
        return True
    if name.endswith((".tmp", ".temp", ".bak")):
        return True
    if name.endswith((".swp", ".swo")):
        return True
    if "___jb_" in lower:
        return True
    return False


def _is_interesting(path: str) -> bool:
    if _is_ignored_artifact(path):
        return False
    lower = path.replace("\\", "/").lower()
    return lower.endswith(_SUFFIXES)


def _split_argv(argv: list[str]) -> tuple[list[str], list[str]]:
    if "--" in argv:
        i = argv.index("--")
        return argv[:i], argv[i + 1 :]
    return argv, []


class _Debounced:
    def __init__(self, delay_s: float, fn: object) -> None:
        self._delay_s = delay_s
        self._fn = fn
        self._timer: threading.Timer | None = None
        self._lock = threading.Lock()

    def ping(self) -> None:
        with self._lock:
            if self._timer is not None:
                self._timer.cancel()
            self._timer = threading.Timer(self._delay_s, self._fire)
            self._timer.daemon = True
            self._timer.start()

    def _fire(self) -> None:
        with self._lock:
            self._timer = None
        self._fn()  # type: ignore[misc]

    def cancel(self) -> None:
        with self._lock:
            if self._timer is not None:
                self._timer.cancel()
                self._timer = None


class _WatchHandler(FileSystemEventHandler):
    def __init__(self, on_change: object) -> None:
        super().__init__()
        self._on_change = on_change

    def on_modified(self, event: object) -> None:
        if getattr(event, "is_directory", False):
            return
        if _is_interesting(getattr(event, "src_path", "")):
            self._on_change()  # type: ignore[misc]

    def on_created(self, event: object) -> None:
        self.on_modified(event)


class Runner:
    def __init__(self, app_argv: list[str]) -> None:
        self._app_argv = app_argv
        self._proc: subprocess.Popen[bytes] | None = None

    def start(self) -> None:
        self.stop()
        cmd = [sys.executable, "-m", "radialdock.app", *self._app_argv]
        env = os.environ.copy()
        env["RADIALDOCK_DEV"] = "1"
        print(f"[dev_watch] starting: {' '.join(cmd)}", flush=True)
        self._proc = subprocess.Popen(
            cmd,
            cwd=str(_REPO_ROOT),
            env=env,
        )

    def stop(self) -> None:
        if self._proc is None:
            return
        if self._proc.poll() is not None:
            self._proc = None
            return
        self._proc.terminate()
        try:
            self._proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            self._proc.kill()
            self._proc.wait(timeout=3)
        self._proc = None


def main() -> int:
    watch_argv, app_argv = _split_argv(sys.argv[1:])
    parser = argparse.ArgumentParser(
        description="Watch src/radialdock and ui/; restart radialdock.app on changes.",
    )
    parser.add_argument(
        "--debounce",
        type=float,
        default=0.35,
        metavar="SEC",
        help="Wait this long after the last change before restarting (default: 0.35).",
    )
    args = parser.parse_args(watch_argv)

    if not _SRC.is_dir():
        print(f"[dev_watch] missing {_SRC}", file=sys.stderr)
        return 1
    if not _UI.is_dir():
        print(f"[dev_watch] missing {_UI}", file=sys.stderr)
        return 1

    runner = Runner(app_argv)

    def restart() -> None:
        print("[dev_watch] change detected — restarting…", flush=True)
        runner.start()

    debounced = _Debounced(args.debounce, restart)

    def on_change() -> None:
        debounced.ping()

    handler = _WatchHandler(on_change)
    observer = Observer()
    observer.schedule(handler, str(_SRC), recursive=True)
    observer.schedule(handler, str(_UI), recursive=True)

    runner.start()
    observer.start()
    print(
        f"[dev_watch] watching {_SRC.name}/ and {_UI.name}/ — Ctrl+C to stop.",
        flush=True,
    )

    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n[dev_watch] stopping.", flush=True)
    finally:
        debounced.cancel()
        observer.stop()
        observer.join(timeout=5)
        runner.stop()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
