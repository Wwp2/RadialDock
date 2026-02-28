from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QObject, Qt, Signal, Slot, QProcess
from PySide6.QtGui import QCursor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from radialdock import install
from radialdock.model import AppModel, AppPaths
from radialdock.win_hotkey import GlobalHotkeyManager


class OverlayController(QObject):
    hotkeyTriggered = Signal(int, int)
    hideRequested = Signal()

    def __init__(self, model: AppModel, launch_args: list[str]) -> None:
        super().__init__()
        self._model = model
        self._launch_args = list(launch_args)

    def on_hotkey(self) -> None:
        pos = QCursor.pos()
        self.hotkeyTriggered.emit(pos.x(), pos.y())

    @Slot()
    def requestHide(self) -> None:
        self.hideRequested.emit()

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


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Radial Dock Launcher")
    parser.add_argument("--install", action="store_true", help="Install the app")
    parser.add_argument("--uninstall", action="store_true", help="Uninstall the app")
    parser.add_argument("--portable", action="store_true", help="Run in portable mode")
    return parser.parse_args(argv)


def configure_high_dpi() -> None:
    # Qt 6 enables high-DPI scaling by default. Keep rounding predictable.
    if hasattr(QApplication, "setHighDpiScaleFactorRoundingPolicy"):
        QApplication.setHighDpiScaleFactorRoundingPolicy(
            Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
        )


def resolve_ui_dir() -> Path:
    root = Path(__file__).resolve().parents[2]
    return root / "ui"


def main(argv: list[str] | None = None) -> int:
    launch_args = list(argv or sys.argv[1:])
    args = parse_args(launch_args)

    if args.install:
        return install.install_self()
    if args.uninstall:
        return install.uninstall_self()

    configure_high_dpi()
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    paths = AppPaths.from_environment(portable=args.portable)
    model = AppModel(paths=paths)
    controller = OverlayController(model, launch_args)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", controller)
    engine.rootContext().setContextProperty("appModel", model)

    ui_dir = resolve_ui_dir()
    engine.addImportPath(str(ui_dir))
    engine.load(str(ui_dir / "Main.qml"))

    if not engine.rootObjects():
        return 1

    hotkey = GlobalHotkeyManager(parent=app)
    hotkey.activated.connect(controller.on_hotkey)
    if not hotkey.register_from_string(model.settings.hotkey):
        print(f"Failed to register global hotkey: {model.settings.hotkey}", file=sys.stderr)
        return 2

    exit_code = app.exec()
    hotkey.unregister()
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
