from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QObject, Qt, Signal
from PySide6.QtGui import QCursor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from radialdock import install
from radialdock.model import AppModel, AppPaths
from radialdock.win_hotkey import GlobalHotkeyManager


class OverlayController(QObject):
    hotkeyTriggered = Signal(int, int)
    hideRequested = Signal()

    def __init__(self, model: AppModel) -> None:
        super().__init__()
        self._model = model

    def on_hotkey(self) -> None:
        pos = QCursor.pos()
        self.hotkeyTriggered.emit(pos.x(), pos.y())


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
    args = parse_args(argv or sys.argv[1:])

    if args.install:
        return install.install_self()
    if args.uninstall:
        return install.uninstall_self()

    configure_high_dpi()
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    paths = AppPaths.from_environment(portable=args.portable)
    model = AppModel(paths=paths)
    controller = OverlayController(model)

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
