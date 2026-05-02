from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QObject, Property, Qt, Signal, Slot, QProcess, QTimer
from PySide6.QtGui import QCursor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication, QFileDialog

from radialdock import install
from radialdock.model import AppModel, AppPaths
from radialdock.win_hotkey import GlobalHotkeyManager, HotkeySpec, normalize_hotkey, parse_hotkey


FORBIDDEN_MOUSE_SHORTCUTS = {"MouseLeft", "MouseRight"}
RESTART_TRACE_FILENAME = "restart_trace.log"


def restart_trace_path(paths: AppPaths | None = None, portable: bool = False) -> Path:
    if paths is not None:
        return paths.config_dir / RESTART_TRACE_FILENAME
    return AppPaths.from_environment(portable=portable).config_dir / RESTART_TRACE_FILENAME


def write_restart_trace(message: str, trace_path: Path | None = None, portable: bool = False) -> None:
    try:
        target = trace_path or restart_trace_path(portable=portable)
        target.parent.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now().isoformat(timespec="milliseconds")
        with target.open("a", encoding="utf-8") as handle:
            handle.write(f"{timestamp} pid={os.getpid()} {message}\n")
    except OSError:
        pass


class OverlayController(QObject):
    hotkeyTriggered = Signal(int, int)
    shortcutLaunchRequested = Signal()
    hideRequested = Signal()
    hotkeyApplyResult = Signal(bool, str, str)
    launchOnStartupChanged = Signal()
    settingsTransferResult = Signal(bool, str)

    def __init__(
        self,
        model: AppModel,
        launch_args: list[str],
        hotkey_manager: GlobalHotkeyManager,
    ) -> None:
        super().__init__()
        self._model = model
        self._launch_args = [arg for arg in launch_args if arg != "--shortcut-launch"]
        self._hotkey_manager = hotkey_manager
        self._suppress_model_hotkey_apply = False
        self._model.hotkeyChanged.connect(self._apply_model_hotkey)

    def on_hotkey(self) -> None:
        pos = QCursor.pos()
        self.hotkeyTriggered.emit(pos.x(), pos.y())

    @Slot()
    def requestShortcutLaunch(self) -> None:
        self.shortcutLaunchRequested.emit()

    def _is_forbidden_shortcut(self, spec: HotkeySpec) -> bool:
        return spec.kind == "mouse" and spec.mouse_button in FORBIDDEN_MOUSE_SHORTCUTS

    @Slot()
    def requestHide(self) -> None:
        self.hideRequested.emit()

    @Slot(result=bool)
    def resetHotkeyToDefault(self) -> bool:
        return self.trySetHotkey("Ctrl+Space")

    @Slot()
    def resetAllQuickSettings(self) -> None:
        self._model.resetQuickSettings()

    @Slot()
    def exportSettingsOnly(self) -> None:
        self._export_settings(include_items=False)

    @Slot()
    def exportSettingsAndDock(self) -> None:
        self._export_settings(include_items=True)

    @Slot()
    def importSettings(self) -> None:
        parent = QApplication.activeWindow()
        start_dir = str(self._model.paths.config_dir)
        selected_path, _ = QFileDialog.getOpenFileName(
            parent,
            "Import RadialDock Settings",
            start_dir,
            "RadialDock Backup (*.radialdock.json *.json);;JSON Files (*.json);;All Files (*)",
        )
        if not selected_path:
            return

        try:
            payload = json.loads(Path(selected_path).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            self.settingsTransferResult.emit(False, "Could not read the selected backup file.")
            return

        success, message = self._model.import_payload(payload)
        self.settingsTransferResult.emit(success, message)

    def _export_settings(self, include_items: bool) -> None:
        parent = QApplication.activeWindow()
        default_stem = "radialdock-settings-and-dock" if include_items else "radialdock-settings"
        default_name = f"{default_stem}-{self._model.appVersion}.radialdock.json"
        start_path = str(self._model.paths.config_dir / default_name)
        selected_path, _ = QFileDialog.getSaveFileName(
            parent,
            "Export RadialDock Settings",
            start_path,
            "RadialDock Backup (*.radialdock.json *.json);;JSON Files (*.json);;All Files (*)",
        )
        if not selected_path:
            return

        target = Path(selected_path)
        if not target.suffix:
            target = target.with_suffix(".radialdock.json")
        elif target.suffix.lower() == ".radialdock":
            target = target.with_suffix(".radialdock.json")

        payload = self._model.export_payload(include_items=include_items)
        try:
            target.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        except OSError:
            self.settingsTransferResult.emit(False, "Could not write the export file.")
            return

        if include_items:
            self.settingsTransferResult.emit(True, "Settings and dock items exported.")
        else:
            self.settingsTransferResult.emit(True, "Settings exported.")

    def get_launch_on_startup_enabled(self) -> bool:
        return install.is_startup_enabled()

    def set_launch_on_startup_enabled(self, value: bool) -> None:
        install.set_startup_enabled(bool(value), launch_args=self._launch_args)
        self.launchOnStartupChanged.emit()

    @Slot()
    def quitApp(self) -> None:
        app = QApplication.instance()
        if app is not None:
            app.quit()

    @staticmethod
    def _ps_quote(value: str) -> str:
        return "'" + str(value).replace("'", "''") + "'"

    def _restart_target(self) -> tuple[str, list[str], str]:
        restart_args = [arg for arg in [*self._launch_args, "--shortcut-launch"] if arg]
        if getattr(sys, "frozen", False):
            program = sys.executable
            arguments = restart_args
            working_directory = str(Path(sys.executable).resolve().parent)
        else:
            program = sys.executable
            arguments = ["-m", "radialdock.app", *restart_args]
            working_directory = str(Path(__file__).resolve().parents[2])
        return program, arguments, working_directory

    @staticmethod
    def _restart_environment() -> dict[str, str]:
        env = os.environ.copy()
        for key in list(env):
            if key.startswith("_PYI"):
                env.pop(key, None)
        env.pop("_MEIPASS2", None)
        env["PYINSTALLER_RESET_ENVIRONMENT"] = "1"
        return env

    @staticmethod
    def _cmd_quote(value: str) -> str:
        return '"' + str(value).replace('"', '""') + '"'

    def _write_restart_helper_script(
        self,
        program: str,
        arguments: list[str],
        working_directory: str,
        trace_path: Path,
    ) -> Path:
        helper_path = Path(tempfile.gettempdir()) / f"radialdock-restart-{os.getpid()}.cmd"
        argument_string = subprocess.list2cmdline(arguments)
        lines = [
            "@echo off",
            "setlocal",
            f'set "TRACE_PATH={trace_path}"',
            '>>"%TRACE_PATH%" echo %date% %time% helper started',
            "timeout /t 1 /nobreak >nul",
            '>>"%TRACE_PATH%" echo %date% %time% helper delay complete',
            'set "PYINSTALLER_RESET_ENVIRONMENT=1"',
            'set "_MEIPASS2="',
            'set "_PYI_APPLICATION_HOME_DIR="',
            'set "_PYI_ARCHIVE_FILE="',
            'set "_PYI_PARENT_PROCESS_LEVEL="',
            f'start "" /d {self._cmd_quote(working_directory)} {self._cmd_quote(program)} {argument_string}'.rstrip(),
            'set "START_RC=%ERRORLEVEL%"',
            '>>"%TRACE_PATH%" echo %date% %time% helper start issued errorlevel=%START_RC%',
            'del /f /q "%~f0" >nul 2>&1',
        ]
        helper_path.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")
        return helper_path

    def _schedule_restart(
        self,
        program: str,
        arguments: list[str],
        working_directory: str,
        trace_path: Path,
    ) -> bool:
        if sys.platform == "win32":
            helper_path = self._write_restart_helper_script(program, arguments, working_directory, trace_path)
            creationflags = (
                getattr(subprocess, "DETACHED_PROCESS", 0)
                | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
                | getattr(subprocess, "CREATE_NO_WINDOW", 0)
            )
            try:
                subprocess.Popen(
                    ["cmd.exe", "/c", str(helper_path)],
                    cwd=working_directory,
                    env=self._restart_environment(),
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    close_fds=True,
                    creationflags=creationflags,
                )
            except OSError as exc:
                write_restart_trace(f"restart helper launch failed: {exc}", trace_path)
                return False
            return True

        started = QProcess.startDetached(program, arguments)
        if isinstance(started, tuple):
            started = bool(started[0])
        else:
            started = bool(started)
        if not started:
            write_restart_trace("restart helper launch failed on non-Windows path", trace_path)
        return started

    @Slot()
    def restartApp(self) -> None:
        trace_path = restart_trace_path(self._model.paths)
        program, arguments, working_directory = self._restart_target()
        stripped_keys = sorted(
            key for key in os.environ if key.startswith("_PYI") or key == "_MEIPASS2"
        )
        write_restart_trace(
            f"restart requested program={program!r} arguments={arguments!r} cwd={working_directory!r} stripped_env={stripped_keys!r}",
            trace_path,
        )
        started = self._schedule_restart(program, arguments, working_directory, trace_path)
        write_restart_trace(f"restart helper scheduled={started}", trace_path)
        if started:
            write_restart_trace("restart quitting current instance", trace_path)
            self.quitApp()

    @Slot(str, result=bool)
    def trySetHotkey(self, hotkey: str) -> bool:
        candidate = str(hotkey).strip()
        try:
            spec = parse_hotkey(candidate)
        except ValueError as exc:
            self.hotkeyApplyResult.emit(False, str(exc), self._model.hotkey)
            return False

        if self._is_forbidden_shortcut(spec):
            self.hotkeyApplyResult.emit(
                False,
                "Left and right mouse buttons are reserved for the UI and cannot be used as launch shortcuts.",
                self._model.hotkey,
            )
            return False

        if not self._hotkey_manager.register_spec(spec):
            self.hotkeyApplyResult.emit(
                False,
                "Windows could not register that shortcut. It may already be in use.",
                self._model.hotkey,
            )
            return False

        normalized = normalize_hotkey(candidate)
        self._suppress_model_hotkey_apply = True
        self._model.hotkey = normalized
        self._suppress_model_hotkey_apply = False
        self.hotkeyApplyResult.emit(True, "Shortcut updated.", normalized)
        return True

    @Slot()
    def _apply_model_hotkey(self) -> None:
        if self._suppress_model_hotkey_apply:
            return
        try:
            spec = parse_hotkey(self._model.hotkey)
        except ValueError:
            spec = parse_hotkey("Ctrl+Space")

        if self._is_forbidden_shortcut(spec):
            self._suppress_model_hotkey_apply = True
            self._model.hotkey = "Ctrl+Space"
            self._suppress_model_hotkey_apply = False
            spec = parse_hotkey("Ctrl+Space")

        self._hotkey_manager.register_spec(spec)

    launchOnStartupEnabled = Property(
        bool,
        get_launch_on_startup_enabled,
        set_launch_on_startup_enabled,
        notify=launchOnStartupChanged,
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Radial Dock Launcher")
    parser.add_argument("--install", action="store_true", help="Install the app")
    parser.add_argument("--uninstall", action="store_true", help="Uninstall the app")
    parser.add_argument(
        "--silent",
        action="store_true",
        help="Use silent install/uninstall defaults with no installer prompts",
    )
    parser.add_argument("--portable", action="store_true", help="Run in portable mode")
    parser.add_argument(
        "--shortcut-launch",
        action="store_true",
        help="Internal flag for Start Menu/Desktop shortcut launches",
    )
    return parser.parse_args(argv)


def configure_high_dpi() -> None:
    # Qt 6 enables high-DPI scaling by default. Keep rounding predictable.
    if hasattr(QApplication, "setHighDpiScaleFactorRoundingPolicy"):
        QApplication.setHighDpiScaleFactorRoundingPolicy(
            Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
        )


def resolve_ui_dir() -> Path:
    if getattr(sys, "frozen", False):
        bundle_root = getattr(sys, "_MEIPASS", "")
        if bundle_root:
            return Path(bundle_root) / "ui"
    root = Path(__file__).resolve().parents[2]
    return root / "ui"


def main(argv: list[str] | None = None) -> int:
    launch_args = list(argv or sys.argv[1:])
    args = parse_args(launch_args)

    if args.install:
        return install.install_self(launch_args, silent=args.silent)
    if args.uninstall:
        return install.uninstall_self(silent=args.silent)
    if (
        not args.portable
        and os.environ.get("RADIALDOCK_DEV") != "1"
        and install.should_offer_manage_prompt()
    ):
        if install.is_installed():
            if install.offer_uninstall_prompt():
                return install.uninstall_self()
        else:
            if install.offer_install_prompt():
                return install.install_self(launch_args)

    configure_high_dpi()
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    paths = AppPaths.from_environment(portable=args.portable)
    trace_path = restart_trace_path(paths)
    write_restart_trace(
        f"process boot argv={launch_args!r} frozen={getattr(sys, 'frozen', False)} exe={sys.executable!r} cwd={os.getcwd()!r}",
        trace_path,
    )
    model = AppModel(paths=paths)
    hotkey = GlobalHotkeyManager(parent=app)
    controller = OverlayController(model, launch_args, hotkey)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", controller)
    engine.rootContext().setContextProperty("appModel", model)

    ui_dir = resolve_ui_dir()
    engine.addImportPath(str(ui_dir))
    engine.load(str(ui_dir / "Main.qml"))

    if not engine.rootObjects():
        write_restart_trace("qml load failed", trace_path)
        return 1

    hotkey.activated.connect(controller.on_hotkey)
    try:
        initial_spec = parse_hotkey(model.settings.hotkey)
    except ValueError:
        model.hotkey = "Ctrl+Space"
        initial_spec = parse_hotkey(model.settings.hotkey)
    if controller._is_forbidden_shortcut(initial_spec):
        model.hotkey = "Ctrl+Space"
        initial_spec = parse_hotkey(model.settings.hotkey)

    if not hotkey.register_spec(initial_spec):
        write_restart_trace(f"hotkey registration failed for {model.settings.hotkey!r}", trace_path)
        print(f"Failed to register global hotkey: {model.settings.hotkey}", file=sys.stderr)
        return 2

    write_restart_trace(f"startup ready hotkey={model.settings.hotkey!r}", trace_path)
    QTimer.singleShot(900, model.warmStartupCaches)

    if args.shortcut_launch or model.startupMessageEnabled:
        QTimer.singleShot(0, controller.requestShortcutLaunch)

    exit_code = app.exec()
    write_restart_trace(f"app exiting code={exit_code}", trace_path)
    hotkey.unregister()
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())


