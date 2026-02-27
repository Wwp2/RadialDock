from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path

from PySide6.QtCore import QObject, Property, Signal


APP_DIR_NAME = "RadialDock"


@dataclass
class DockItem:
    path: str
    label: str
    kind: str


@dataclass
class Settings:
    hotkey: str = "Ctrl+Space"
    refresh_on_open: bool = True
    items: list[DockItem] = field(default_factory=list)


@dataclass
class AppPaths:
    config_dir: Path
    cache_dir: Path
    config_file: Path

    @classmethod
    def from_environment(cls, portable: bool) -> "AppPaths":
        if portable:
            root = Path.cwd() / ".radialdock"
        else:
            appdata = Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
            root = appdata / APP_DIR_NAME
        cache = root / "cache"
        return cls(config_dir=root, cache_dir=cache, config_file=root / "config.json")


class AppModel(QObject):
    refreshOnOpenChanged = Signal()

    def __init__(self, paths: AppPaths) -> None:
        super().__init__()
        self.paths = paths
        self.settings = self._load_settings()

    def _load_settings(self) -> Settings:
        self.paths.config_dir.mkdir(parents=True, exist_ok=True)
        self.paths.cache_dir.mkdir(parents=True, exist_ok=True)
        if not self.paths.config_file.exists():
            settings = Settings()
            self._save_settings(settings)
            return settings

        try:
            raw = json.loads(self.paths.config_file.read_text(encoding="utf-8"))
            items = [
                DockItem(
                    path=item.get("path", ""),
                    label=item.get("label", ""),
                    kind=item.get("kind", "file"),
                )
                for item in raw.get("items", [])
            ]
            return Settings(
                hotkey=raw.get("hotkey", "Ctrl+Space"),
                refresh_on_open=bool(raw.get("refresh_on_open", True)),
                items=items,
            )
        except (json.JSONDecodeError, OSError):
            settings = Settings()
            self._save_settings(settings)
            return settings

    def _save_settings(self, settings: Settings) -> None:
        payload = asdict(settings)
        self.paths.config_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    def get_refresh_on_open(self) -> bool:
        return self.settings.refresh_on_open

    def set_refresh_on_open(self, value: bool) -> None:
        if self.settings.refresh_on_open == value:
            return
        self.settings.refresh_on_open = value
        self._save_settings(self.settings)
        self.refreshOnOpenChanged.emit()

    refreshOnOpen = Property(
        bool,
        get_refresh_on_open,
        set_refresh_on_open,
        notify=refreshOnOpenChanged,
    )
