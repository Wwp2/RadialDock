from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QObject, Property, Qt, Signal, Slot, QProcess, QTimer
from PySide6.QtGui import QCursor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from radialdock import install
from radialdock.model import AppModel, AppPaths
from radialdock.win_hotkey import GlobalHotkeyManager, HotkeySpec, normalize_hotkey, parse_hotkey


FORBIDDEN_MOUSE_SHORTCUTS = {"MouseLeft", "MouseRight"}


class OverlayController(QObject):
    hotkeyTriggered = Signal(int, int)
    shortcutLaunchRequested = Signal()
    hideRequested = Signal()
    hotkeyApplyResult = Signal(bool, str, str)
    launchOnStartupChanged = Signal()

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

    @Slot()
    def restartApp(self) -> None:
        if getattr(sys, "frozen", False):
            program = sys.executable
            arguments = self._launch_args
        else:
            program = sys.executable
            arguments = ["-m", "radialdock.app", *self._launch_args]

        started = QProcess.startDetached(program, arguments)
        if started:
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
        return install.install_self(launch_args)
    if args.uninstall:
        return install.uninstall_self()
    if not args.portable and install.should_offer_manage_prompt():
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
        print(f"Failed to register global hotkey: {model.settings.hotkey}", file=sys.stderr)
        return 2

    if args.shortcut_launch or model.startupMessageEnabled:
        QTimer.singleShot(0, controller.requestShortcutLaunch)

    exit_code = app.exec()
    hotkey.unregister()
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
