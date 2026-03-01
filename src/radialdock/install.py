from __future__ import annotations

import ctypes
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import asdict, dataclass
from pathlib import Path

try:
    import pythoncom
    from win32com.client import Dispatch
except ImportError:  # pragma: no cover - dependency is part of requirements on Windows
    pythoncom = None
    Dispatch = None


APP_DIR_NAME = "RadialDock"
APP_EXE_NAME = "RadialDock.exe"
INSTALL_MARKER = "install.json"
START_MENU_SHORTCUT_NAME = "RadialDock.lnk"
DESKTOP_SHORTCUT_NAME = "RadialDock.lnk"
STARTUP_SHORTCUT_NAME = "RadialDock Startup.lnk"

MB_ICONQUESTION = 0x20
MB_ICONINFORMATION = 0x40
MB_ICONWARNING = 0x30
MB_YESNO = 0x04
MB_OK = 0x00
IDYES = 6


@dataclass
class LaunchSpec:
    target_path: str
    arguments: str
    working_dir: str
    icon_path: str


def local_app_data() -> Path:
    return Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local")))


def roaming_app_data() -> Path:
    return Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))


def install_root() -> Path:
    return local_app_data() / APP_DIR_NAME


def marker_path() -> Path:
    return install_root() / INSTALL_MARKER


def installed_exe_path() -> Path:
    return install_root() / APP_EXE_NAME


def start_menu_shortcut_path() -> Path:
    return roaming_app_data() / "Microsoft" / "Windows" / "Start Menu" / "Programs" / START_MENU_SHORTCUT_NAME


def desktop_shortcut_path() -> Path:
    return Path(os.environ.get("USERPROFILE", str(Path.home()))) / "Desktop" / DESKTOP_SHORTCUT_NAME


def startup_shortcut_path() -> Path:
    return roaming_app_data() / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "Startup" / STARTUP_SHORTCUT_NAME


def is_installed() -> bool:
    return marker_path().exists()


def is_startup_enabled() -> bool:
    return startup_shortcut_path().exists()


def _message_box(title: str, text: str, flags: int) -> int:
    return int(
        ctypes.windll.user32.MessageBoxW(
            None,
            text,
            title,
            flags,
        )
    )


def _ask_yes_no(title: str, text: str) -> bool:
    return _message_box(title, text, MB_YESNO | MB_ICONQUESTION) == IDYES


def _show_info(title: str, text: str) -> None:
    _message_box(title, text, MB_OK | MB_ICONINFORMATION)


def _show_warning(title: str, text: str) -> None:
    _message_box(title, text, MB_OK | MB_ICONWARNING)


def should_offer_manage_prompt() -> bool:
    if not getattr(sys, "frozen", False):
        return False
    try:
        return Path(sys.executable).resolve() != installed_exe_path().resolve()
    except OSError:
        return True


def offer_install_prompt() -> bool:
    return _ask_yes_no(
        "RadialDock",
        "RadialDock is not installed yet.\n\nDo you want to install it now?",
    )


def offer_uninstall_prompt() -> bool:
    return _ask_yes_no(
        "RadialDock",
        "RadialDock is already installed.\n\nDo you want to uninstall it now?",
    )


def _load_marker() -> dict[str, object]:
    if not marker_path().exists():
        return {}
    try:
        return json.loads(marker_path().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _save_marker(launch_spec: LaunchSpec) -> None:
    payload = {
        "launch_spec": asdict(launch_spec),
        "installed": True,
    }
    install_root().mkdir(parents=True, exist_ok=True)
    marker_path().write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _pythonw_path() -> Path:
    candidate = Path(sys.executable).with_name("pythonw.exe")
    if candidate.exists():
        return candidate
    return Path(sys.executable)


def _source_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _normalized_launch_args(launch_args: list[str] | None = None) -> list[str]:
    args = list(launch_args or sys.argv[1:])
    filtered = [arg for arg in args if arg not in {"--install", "--uninstall"}]
    return filtered


def _current_launch_spec(
    launch_args: list[str] | None = None,
    prefer_installed: bool = False,
) -> LaunchSpec:
    marker = _load_marker()
    if prefer_installed and marker.get("launch_spec"):
        launch_spec = marker["launch_spec"]
        if isinstance(launch_spec, dict):
            return LaunchSpec(
                target_path=str(launch_spec.get("target_path", "")),
                arguments=str(launch_spec.get("arguments", "")),
                working_dir=str(launch_spec.get("working_dir", "")),
                icon_path=str(launch_spec.get("icon_path", "")),
            )

    args = _normalized_launch_args(launch_args)
    if getattr(sys, "frozen", False):
        target = Path(sys.executable)
        return LaunchSpec(
            target_path=str(target),
            arguments="",
            working_dir=str(target.parent),
            icon_path=str(target),
        )

    target = _pythonw_path()
    module_args = ["-m", "radialdock.app", *args]
    return LaunchSpec(
        target_path=str(target),
        arguments=subprocess.list2cmdline(module_args),
        working_dir=str(_source_root()),
        icon_path=str(target),
    )


def _create_shortcut(shortcut_path: Path, launch_spec: LaunchSpec) -> None:
    if Dispatch is None:
        raise RuntimeError("pywin32 is required for shortcut creation.")

    shortcut_path.parent.mkdir(parents=True, exist_ok=True)

    if pythoncom is not None:
        pythoncom.CoInitialize()
    try:
        shell = Dispatch("WScript.Shell")
        shortcut = shell.CreateShortcut(str(shortcut_path))
        shortcut.TargetPath = launch_spec.target_path
        shortcut.Arguments = launch_spec.arguments
        shortcut.WorkingDirectory = launch_spec.working_dir
        if launch_spec.icon_path:
            shortcut.IconLocation = launch_spec.icon_path
        shortcut.Save()
    finally:
        if pythoncom is not None:
            pythoncom.CoUninitialize()


def _remove_path(path: Path) -> None:
    try:
        if path.exists():
            path.unlink()
    except OSError:
        pass


def _terminate_running_runtime() -> None:
    current_exe = Path(sys.executable)
    target_exe = installed_exe_path()

    try:
        if current_exe.exists() and current_exe.resolve() == target_exe.resolve():
            return
    except OSError:
        pass

    subprocess.run(
        ["taskkill", "/IM", APP_EXE_NAME, "/F", "/T"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=0x08000000,  # CREATE_NO_WINDOW
    )
    time.sleep(0.5)


def set_startup_enabled(enabled: bool, launch_args: list[str] | None = None) -> bool:
    startup_path = startup_shortcut_path()
    if enabled:
        launch_spec = _current_launch_spec(launch_args=launch_args, prefer_installed=True)
        _create_shortcut(startup_path, launch_spec)
    else:
        _remove_path(startup_path)
    return startup_path.exists()


def install_self(launch_args: list[str] | None = None) -> int:
    target_dir = install_root()
    target_dir.mkdir(parents=True, exist_ok=True)

    create_start_menu = _ask_yes_no(
        "RadialDock Install",
        "Create a Start Menu shortcut?",
    )
    create_desktop = _ask_yes_no(
        "RadialDock Install",
        "Create a desktop shortcut?",
    )
    enable_startup = _ask_yes_no(
        "RadialDock Install",
        "Launch RadialDock automatically when Windows starts?",
    )

    if getattr(sys, "frozen", False):
        source_exe = Path(sys.executable)
        target_exe = installed_exe_path()
        if source_exe.resolve() != target_exe.resolve():
            shutil.copy2(source_exe, target_exe)
        launch_spec = LaunchSpec(
            target_path=str(target_exe),
            arguments="",
            working_dir=str(target_exe.parent),
            icon_path=str(target_exe),
        )
    else:
        # Dev/source-mode install keeps using the current source tree and interpreter.
        launch_spec = _current_launch_spec(launch_args=launch_args, prefer_installed=False)

    if create_start_menu:
        _create_shortcut(start_menu_shortcut_path(), launch_spec)
    else:
        _remove_path(start_menu_shortcut_path())

    if create_desktop:
        _create_shortcut(desktop_shortcut_path(), launch_spec)
    else:
        _remove_path(desktop_shortcut_path())

    if enable_startup:
        _create_shortcut(startup_shortcut_path(), launch_spec)
    else:
        _remove_path(startup_shortcut_path())
    _save_marker(launch_spec)

    summary = [
        f"Install location: {target_dir}",
        "Start Menu shortcut: " + ("Yes" if create_start_menu else "No"),
        "Desktop shortcut: " + ("Yes" if create_desktop else "No"),
        "Start on login: " + ("Yes" if enable_startup else "No"),
    ]
    _show_info("RadialDock Install", "\n".join(summary))
    return 0


def _schedule_self_delete(root: Path, current_exe: Path) -> None:
    temp_script = Path(tempfile.gettempdir()) / "radialdock-uninstall.cmd"
    lines = [
        "@echo off",
        ":waitloop",
        f'tasklist /FI "PID eq {os.getpid()}" | find "{os.getpid()}" >nul',
        "if not errorlevel 1 (",
        "  timeout /t 1 /nobreak >nul",
        "  goto waitloop",
        ")",
        f'del /f /q "{current_exe}" >nul 2>&1',
        f'rmdir /s /q "{root}" >nul 2>&1',
        f'del /f /q "{temp_script}" >nul 2>&1',
    ]
    temp_script.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")
    subprocess.Popen(
        ["cmd.exe", "/c", str(temp_script)],
        creationflags=0x08000000,  # CREATE_NO_WINDOW
        close_fds=True,
    )


def uninstall_self() -> int:
    if not is_installed():
        _show_info("RadialDock Uninstall", "RadialDock is not currently installed.")
        return 0

    _terminate_running_runtime()
    _remove_path(start_menu_shortcut_path())
    _remove_path(desktop_shortcut_path())
    _remove_path(startup_shortcut_path())
    _remove_path(marker_path())

    root = install_root()
    current_exe = Path(sys.executable)

    if getattr(sys, "frozen", False) and root.exists():
        try:
            if current_exe.exists() and current_exe.resolve().is_relative_to(root.resolve()):
                _schedule_self_delete(root, current_exe)
                _show_info(
                    "RadialDock Uninstall",
                    "RadialDock will finish removing itself after this process exits.",
                )
                return 0
        except AttributeError:
            # Python <3.9 fallback not needed in current environment.
            pass

    try:
        if root.exists():
            shutil.rmtree(root)
    except OSError as exc:
        _show_warning("RadialDock Uninstall", f"Uninstall failed: {exc}")
        return 1

    _show_info("RadialDock Uninstall", "RadialDock has been removed.")
    return 0
