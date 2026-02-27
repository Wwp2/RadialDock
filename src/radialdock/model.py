from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path

from PySide6.QtCore import QByteArray, QBuffer, QIODevice, QFileInfo, QObject, Property, Qt, Signal, Slot
from PySide6.QtGui import QColor, QIcon, QPainter, QPixmap
from PySide6.QtWidgets import QFileIconProvider


APP_DIR_NAME = "RadialDock"
DEFAULT_ITEM_COLORS = [
    "#FF7B6C",
    "#8D9BFF",
    "#63D5C2",
    "#F9B26E",
    "#62B9FF",
    "#DD8DFF",
    "#83E37B",
    "#F0DF87",
]


@dataclass
class DockItem:
    path: str
    label: str
    kind: str
    color: str = "#62B9FF"


def default_ring_items() -> list[DockItem]:
    return [
        DockItem(path="", label="Steam", kind="app", color="#FF7B6C"),
        DockItem(path="", label="Discord", kind="app", color="#8D9BFF"),
        DockItem(path="", label="Downloads", kind="folder", color="#63D5C2"),
        DockItem(path="", label="Photos", kind="folder", color="#F9B26E"),
        DockItem(path="", label="VS Code", kind="app", color="#62B9FF"),
        DockItem(path="", label="Music", kind="folder", color="#DD8DFF"),
        DockItem(path="", label="Maps", kind="app", color="#83E37B"),
        DockItem(path="", label="Docs", kind="folder", color="#F0DF87"),
    ]


@dataclass
class Settings:
    hotkey: str = "Ctrl+Space"
    refresh_on_open: bool = True
    items: list[DockItem] = field(default_factory=default_ring_items)


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
    ringItemsChanged = Signal()

    def __init__(self, paths: AppPaths) -> None:
        super().__init__()
        self.paths = paths
        self.settings = self._load_settings()
        self._icon_provider = QFileIconProvider()
        self._icon_cache: dict[str, str] = {}

    def _load_settings(self) -> Settings:
        self.paths.config_dir.mkdir(parents=True, exist_ok=True)
        self.paths.cache_dir.mkdir(parents=True, exist_ok=True)
        if not self.paths.config_file.exists():
            settings = Settings(items=default_ring_items())
            self._save_settings(settings)
            return settings

        try:
            raw = json.loads(self.paths.config_file.read_text(encoding="utf-8"))
            items = [
                DockItem(
                    path=item.get("path", ""),
                    label=item.get("label", ""),
                    kind=item.get("kind", "file"),
                    color=item.get(
                        "color",
                        self._color_for_item(item.get("path", ""), item.get("label", ""), index),
                    ),
                )
                for index, item in enumerate(raw.get("items", []))
            ]
            return Settings(
                hotkey=raw.get("hotkey", "Ctrl+Space"),
                refresh_on_open=bool(raw.get("refresh_on_open", True)),
                items=items,
            )
        except (json.JSONDecodeError, OSError):
            settings = Settings(items=default_ring_items())
            self._save_settings(settings)
            return settings

    def _save_settings(self, settings: Settings) -> None:
        payload = asdict(settings)
        self.paths.config_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    def _color_for_item(self, path: str, label: str, index: int) -> str:
        seed = path or label or str(index)
        value = sum(ord(char) for char in seed)
        return DEFAULT_ITEM_COLORS[value % len(DEFAULT_ITEM_COLORS)]

    def get_refresh_on_open(self) -> bool:
        return self.settings.refresh_on_open

    def set_refresh_on_open(self, value: bool) -> None:
        if self.settings.refresh_on_open == value:
            return
        self.settings.refresh_on_open = value
        self._save_settings(self.settings)
        self.refreshOnOpenChanged.emit()

    def get_ring_items(self) -> list[dict[str, str]]:
        return [asdict(item) for item in self.settings.items]

    @Slot("QVariantList")
    def saveRingItems(self, items: list[object]) -> None:
        parsed_items: list[DockItem] = []
        for index, raw_item in enumerate(items):
            if not isinstance(raw_item, dict):
                continue
            path = str(raw_item.get("path", ""))
            label = str(raw_item.get("label", ""))
            kind = str(raw_item.get("kind", "file") or "file")
            color = str(raw_item.get("color", "")).strip()
            if not label:
                label = Path(path).name if path else "Item"
            if not color:
                color = self._color_for_item(path, label, index)
            parsed_items.append(DockItem(path=path, label=label, kind=kind, color=color))

        self.settings.items = parsed_items
        self._save_settings(self.settings)
        self.ringItemsChanged.emit()

    @Slot(str, str, str, result=str)
    def iconDataUrl(self, path: str, kind: str, label: str) -> str:
        cache_key = f"{path}|{kind}|{label}"
        if cache_key in self._icon_cache:
            return self._icon_cache[cache_key]

        icon = self._icon_for_item(path=path, kind=kind)
        pixmap = icon.pixmap(64, 64)
        if pixmap.isNull():
            pixmap = self._fallback_pixmap(label)

        data_url = self._pixmap_to_data_url(pixmap)
        self._icon_cache[cache_key] = data_url
        return data_url

    def _icon_for_item(self, path: str, kind: str) -> QIcon:
        if path:
            file_info = QFileInfo(path)
            if file_info.exists():
                return self._icon_provider.icon(file_info)

        normalized_kind = (kind or "").lower()
        if normalized_kind == "folder":
            return self._icon_provider.icon(QFileIconProvider.IconType.Folder)
        return self._icon_provider.icon(QFileIconProvider.IconType.File)

    def _pixmap_to_data_url(self, pixmap: QPixmap) -> str:
        payload = QByteArray()
        buffer = QBuffer(payload)
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        pixmap.save(buffer, "PNG")
        encoded = bytes(payload.toBase64()).decode("ascii")
        return f"data:image/png;base64,{encoded}"

    def _fallback_pixmap(self, label: str) -> QPixmap:
        pixmap = QPixmap(64, 64)
        pixmap.fill(QColor("#2D4054"))

        painter = QPainter(pixmap)
        painter.setPen(QColor("#EAF4FF"))
        painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, (label[:1] or "?").upper())
        painter.end()
        return pixmap

    refreshOnOpen = Property(
        bool,
        get_refresh_on_open,
        set_refresh_on_open,
        notify=refreshOnOpenChanged,
    )

    ringItems = Property(
        "QVariantList",
        get_ring_items,
        notify=ringItemsChanged,
    )
