from __future__ import annotations

import json
import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from pathlib import Path

from PySide6.QtCore import (
    QByteArray,
    QBuffer,
    QIODevice,
    QFileInfo,
    QMetaObject,
    QObject,
    Property,
    Qt,
    Signal,
    Slot,
)
from PySide6.QtGui import QColor, QIcon, QPainter, QPixmap
from PySide6.QtWidgets import QFileIconProvider

from radialdock.cache import ThumbnailCache
from radialdock.shell_open import open_path


APP_DIR_NAME = "RadialDock"
DEFAULT_ANIMATION_SPEED_SCALE = 0.2
MIN_ANIMATION_SPEED_SCALE = 0.1
MAX_ANIMATION_SPEED_SCALE = 10.0
DEFAULT_ANIMATIONS_ENABLED = True
DEFAULT_CLOSE_AFTER_LAUNCH = True
DEFAULT_FOLDER_COMPACT_THRESHOLD = 50
DEFAULT_PREVIEW_SIZE = (128, 128)
MIN_FOLDER_COMPACT_THRESHOLD = 1
MAX_FOLDER_COMPACT_THRESHOLD = 5000
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
IMAGE_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".bmp",
    ".gif",
    ".webp",
    ".tif",
    ".tiff",
}


def resolve_app_version() -> str:
    version_path: Path
    if getattr(sys, "frozen", False):
        bundle_root = getattr(sys, "_MEIPASS", "")
        if bundle_root:
            version_path = Path(bundle_root) / "VERSION.txt"
        else:
            version_path = Path(sys.executable).resolve().parent / "VERSION.txt"
    else:
        version_path = Path(__file__).resolve().parents[2] / "VERSION.txt"

    try:
        value = version_path.read_text(encoding="utf-8").strip()
        return value or "0.0.0"
    except OSError:
        return "0.0.0"


@dataclass
class DockItem:
    path: str
    label: str
    kind: str
    color: str = "#62B9FF"


def default_ring_items() -> list[DockItem]:
    return []


@dataclass
class Settings:
    hotkey: str = "Ctrl+Space"
    startup_message_enabled: bool = True
    automatic_icon_refresh: bool = True
    automatic_folder_refresh: bool = True
    close_after_launch: bool = DEFAULT_CLOSE_AFTER_LAUNCH
    animation_speed_scale: float = DEFAULT_ANIMATION_SPEED_SCALE
    animations_enabled: bool = DEFAULT_ANIMATIONS_ENABLED
    folder_compact_threshold: int = DEFAULT_FOLDER_COMPACT_THRESHOLD
    folder_cache: dict[str, list[dict[str, str]]] = field(default_factory=dict)
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
        elif cls._should_use_installed_runtime_root():
            root = cls._installed_runtime_root()
        else:
            appdata = Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
            root = appdata / APP_DIR_NAME
        cache = root / "cache"
        return cls(config_dir=root, cache_dir=cache, config_file=root / "config.json")

    @staticmethod
    def _installed_runtime_root() -> Path:
        local_appdata = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local")))
        return local_appdata / APP_DIR_NAME

    @classmethod
    def _should_use_installed_runtime_root(cls) -> bool:
        if not getattr(sys, "frozen", False):
            return False

        try:
            executable = Path(sys.executable).resolve()
        except OSError:
            return False

        runtime_root = cls._installed_runtime_root()
        if executable.name.lower() != "radialdock.exe":
            return False

        try:
            return executable.parent == runtime_root.resolve()
        except OSError:
            return False


class AppModel(QObject):
    hotkeyChanged = Signal()
    startupMessageEnabledChanged = Signal()
    automaticIconRefreshChanged = Signal()
    automaticFolderRefreshChanged = Signal()
    closeAfterLaunchChanged = Signal()
    folderEntriesReady = Signal(str, "QVariantList")
    _folderEntriesResolved = Signal(str, object)
    previewVersionChanged = Signal()
    ringItemsChanged = Signal()
    animationSpeedScaleChanged = Signal()
    animationsEnabledChanged = Signal()
    folderCompactThresholdChanged = Signal()

    def __init__(self, paths: AppPaths) -> None:
        super().__init__()
        self.paths = paths
        self.settings = self._load_settings()
        self._icon_provider = QFileIconProvider()
        self._thumb_cache = ThumbnailCache(paths.cache_dir)
        self._icon_cache: dict[str, str] = {}
        self._preview_version = 0
        self._preview_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="radialdock-preview")
        self._pending_previews: set[tuple[str, tuple[int, int]]] = set()
        self._pending_folder_requests: set[str] = set()
        self._preview_lock = threading.Lock()
        self._folderEntriesResolved.connect(
            self._handle_folder_entries_resolved,
            Qt.ConnectionType.QueuedConnection,
        )
        self._app_version = resolve_app_version()

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
                startup_message_enabled=bool(raw.get("startup_message_enabled", True)),
                automatic_icon_refresh=bool(raw.get("automatic_icon_refresh", True)),
                automatic_folder_refresh=bool(
                    raw.get("automatic_folder_refresh", raw.get("refresh_on_open", True))
                ),
                close_after_launch=bool(raw.get("close_after_launch", DEFAULT_CLOSE_AFTER_LAUNCH)),
                animation_speed_scale=self._sanitize_animation_speed(
                    raw.get("animation_speed_scale", DEFAULT_ANIMATION_SPEED_SCALE)
                ),
                animations_enabled=bool(raw.get("animations_enabled", DEFAULT_ANIMATIONS_ENABLED)),
                folder_compact_threshold=self._sanitize_compact_threshold(
                    raw.get("folder_compact_threshold", DEFAULT_FOLDER_COMPACT_THRESHOLD)
                ),
                folder_cache=self._sanitize_folder_cache(raw.get("folder_cache", {})),
                items=items,
            )
        except (json.JSONDecodeError, OSError):
            settings = Settings(items=default_ring_items())
            self._save_settings(settings)
            return settings

    def _save_settings(self, settings: Settings) -> None:
        payload = asdict(settings)
        self.paths.config_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    def get_hotkey(self) -> str:
        return self.settings.hotkey

    def set_hotkey(self, value: str) -> None:
        normalized = str(value).strip()
        if not normalized or self.settings.hotkey == normalized:
            return
        self.settings.hotkey = normalized
        self._save_settings(self.settings)
        self.hotkeyChanged.emit()

    def get_startup_message_enabled(self) -> bool:
        return self.settings.startup_message_enabled

    def set_startup_message_enabled(self, value: bool) -> None:
        normalized = bool(value)
        if self.settings.startup_message_enabled == normalized:
            return
        self.settings.startup_message_enabled = normalized
        self._save_settings(self.settings)
        self.startupMessageEnabledChanged.emit()

    def get_preview_version(self) -> int:
        return self._preview_version

    def get_app_version(self) -> str:
        return self._app_version

    @Slot()
    def _bump_preview_version(self) -> None:
        self._preview_version += 1
        self.previewVersionChanged.emit()

    def _sanitize_animation_speed(self, value: object) -> float:
        try:
            numeric = float(value)
        except (TypeError, ValueError):
            return DEFAULT_ANIMATION_SPEED_SCALE
        return max(MIN_ANIMATION_SPEED_SCALE, min(MAX_ANIMATION_SPEED_SCALE, numeric))

    def _sanitize_compact_threshold(self, value: object) -> int:
        try:
            numeric = int(value)
        except (TypeError, ValueError):
            return DEFAULT_FOLDER_COMPACT_THRESHOLD
        return max(MIN_FOLDER_COMPACT_THRESHOLD, min(MAX_FOLDER_COMPACT_THRESHOLD, numeric))

    def _sanitize_folder_cache(self, value: object) -> dict[str, list[dict[str, str]]]:
        if not isinstance(value, dict):
            return {}

        sanitized: dict[str, list[dict[str, str]]] = {}
        for folder_path, raw_entries in value.items():
            if not isinstance(folder_path, str) or not isinstance(raw_entries, list):
                continue
            entries: list[dict[str, str]] = []
            for raw_entry in raw_entries[:500]:
                if not isinstance(raw_entry, dict):
                    continue
                entry_path = str(raw_entry.get("path", ""))
                entry_label = str(raw_entry.get("label", ""))
                entry_kind = str(raw_entry.get("kind", "file") or "file")
                entry_icon = str(raw_entry.get("icon", ""))
                entries.append(
                    {
                        "path": entry_path,
                        "label": entry_label,
                        "kind": entry_kind,
                        "icon": entry_icon,
                    }
                )
            sanitized[folder_path] = entries
        return sanitized

    def _color_for_item(self, path: str, label: str, index: int) -> str:
        seed = path or label or str(index)
        value = sum(ord(char) for char in seed)
        return DEFAULT_ITEM_COLORS[value % len(DEFAULT_ITEM_COLORS)]

    def _kind_for_path(self, candidate: Path) -> str:
        if candidate.is_dir():
            return "folder"
        if candidate.suffix.lower() == ".lnk":
            return "shortcut"
        return "file"

    @Slot(str, result=str)
    def pathKind(self, path: str) -> str:
        if not path:
            return "file"
        candidate = Path(path)
        if not candidate.exists():
            if candidate.suffix.lower() == ".lnk":
                return "shortcut"
            return "file"
        return self._kind_for_path(candidate)

    def get_automatic_icon_refresh(self) -> bool:
        return self.settings.automatic_icon_refresh

    def set_automatic_icon_refresh(self, value: bool) -> None:
        normalized = bool(value)
        if self.settings.automatic_icon_refresh == normalized:
            return
        self.settings.automatic_icon_refresh = normalized
        self._save_settings(self.settings)
        self.automaticIconRefreshChanged.emit()

    def get_automatic_folder_refresh(self) -> bool:
        return self.settings.automatic_folder_refresh

    def set_automatic_folder_refresh(self, value: bool) -> None:
        normalized = bool(value)
        if self.settings.automatic_folder_refresh == normalized:
            return
        self.settings.automatic_folder_refresh = normalized
        self._save_settings(self.settings)
        self.automaticFolderRefreshChanged.emit()

    def get_animation_speed_scale(self) -> float:
        return self.settings.animation_speed_scale

    def get_close_after_launch(self) -> bool:
        return self.settings.close_after_launch

    def set_close_after_launch(self, value: bool) -> None:
        normalized = bool(value)
        if self.settings.close_after_launch == normalized:
            return
        self.settings.close_after_launch = normalized
        self._save_settings(self.settings)
        self.closeAfterLaunchChanged.emit()

    def set_animation_speed_scale(self, value: float) -> None:
        sanitized = self._sanitize_animation_speed(value)
        if self.settings.animation_speed_scale == sanitized:
            return
        self.settings.animation_speed_scale = sanitized
        self._save_settings(self.settings)
        self.animationSpeedScaleChanged.emit()

    def get_animations_enabled(self) -> bool:
        return self.settings.animations_enabled

    def set_animations_enabled(self, value: bool) -> None:
        normalized = bool(value)
        if self.settings.animations_enabled == normalized:
            return
        self.settings.animations_enabled = normalized
        self._save_settings(self.settings)
        self.animationsEnabledChanged.emit()

    def get_folder_compact_threshold(self) -> int:
        return self.settings.folder_compact_threshold

    def set_folder_compact_threshold(self, value: int) -> None:
        sanitized = self._sanitize_compact_threshold(value)
        if self.settings.folder_compact_threshold == sanitized:
            return
        self.settings.folder_compact_threshold = sanitized
        self._save_settings(self.settings)
        self.folderCompactThresholdChanged.emit()

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

    @Slot()
    def clearRingItems(self) -> None:
        self.settings.items = []
        self.settings.folder_cache = {}
        self._save_settings(self.settings)
        self.ringItemsChanged.emit()

    @Slot()
    def resetQuickSettings(self) -> None:
        self.settings.startup_message_enabled = True
        self.settings.automatic_icon_refresh = True
        self.settings.automatic_folder_refresh = True
        self.settings.close_after_launch = DEFAULT_CLOSE_AFTER_LAUNCH
        self.settings.hotkey = "Ctrl+Space"
        self.settings.animation_speed_scale = DEFAULT_ANIMATION_SPEED_SCALE
        self.settings.animations_enabled = DEFAULT_ANIMATIONS_ENABLED
        self.settings.folder_compact_threshold = DEFAULT_FOLDER_COMPACT_THRESHOLD
        self._save_settings(self.settings)
        self.hotkeyChanged.emit()
        self.startupMessageEnabledChanged.emit()
        self.automaticIconRefreshChanged.emit()
        self.automaticFolderRefreshChanged.emit()
        self.closeAfterLaunchChanged.emit()
        self.animationSpeedScaleChanged.emit()
        self.animationsEnabledChanged.emit()
        self.folderCompactThresholdChanged.emit()

    @Slot(str, str, str, result=str)
    def iconDataUrl(self, path: str, kind: str, label: str) -> str:
        cache_key = f"{path}|{kind}|{label}"
        if cache_key in self._icon_cache:
            return self._icon_cache[cache_key]

        if kind == "file" and path:
            candidate = Path(path)
            if candidate.suffix.lower() in IMAGE_EXTENSIONS:
                thumb_uri = self._thumb_cache.peek_thumbnail_uri(
                    candidate,
                    size=DEFAULT_PREVIEW_SIZE,
                )
                if thumb_uri:
                    self._icon_cache[cache_key] = thumb_uri
                    return thumb_uri
                self._queue_preview_generation(candidate, DEFAULT_PREVIEW_SIZE)

        icon = self._icon_for_item(path=path, kind=kind)
        pixmap = icon.pixmap(64, 64)
        if pixmap.isNull():
            pixmap = self._fallback_pixmap(label)

        data_url = self._pixmap_to_data_url(pixmap)
        self._icon_cache[cache_key] = data_url
        return data_url

    def _queue_preview_generation(self, source_path: Path, size: tuple[int, int]) -> None:
        if not source_path.exists():
            return

        key = (str(source_path), size)
        with self._preview_lock:
            if key in self._pending_previews:
                return
            self._pending_previews.add(key)

        def worker() -> None:
            try:
                self._thumb_cache.get_thumbnail_uri(source_path, refresh=False, size=size)
                prefix = f"{source_path}|file|"
                stale_keys = [key_name for key_name in self._icon_cache if key_name.startswith(prefix)]
                for key_name in stale_keys:
                    self._icon_cache.pop(key_name, None)
            finally:
                with self._preview_lock:
                    self._pending_previews.discard(key)
                QMetaObject.invokeMethod(self, "_bump_preview_version", Qt.ConnectionType.QueuedConnection)

        self._preview_executor.submit(worker)

    @Slot(str, bool)
    def requestFolderEntries(self, folder_path: str, refresh_on_open: bool) -> None:
        if not folder_path:
            self.folderEntriesReady.emit("", [])
            return

        if not self.settings.automatic_folder_refresh:
            self.folderEntriesReady.emit(folder_path, self.settings.folder_cache.get(folder_path, []))
            return

        with self._preview_lock:
            if folder_path in self._pending_folder_requests:
                return
            self._pending_folder_requests.add(folder_path)

        def worker() -> None:
            try:
                folder = Path(folder_path)
                if not folder.exists() or not folder.is_dir():
                    entries: list[dict[str, str]] = []
                else:
                    try:
                        entries = self._build_folder_entries(folder, refresh_on_open=refresh_on_open)
                    except OSError:
                        entries = []
                self._folderEntriesResolved.emit(folder_path, entries)
            finally:
                with self._preview_lock:
                    self._pending_folder_requests.discard(folder_path)

        self._preview_executor.submit(worker)

    @Slot(str, object)
    def _handle_folder_entries_resolved(self, folder_path: str, entries: object) -> None:
        if isinstance(entries, list):
            normalized_entries = [
                entry for entry in entries
                if isinstance(entry, dict)
            ]
        else:
            normalized_entries = []

        if self.settings.folder_cache.get(folder_path) != normalized_entries:
            self.settings.folder_cache[folder_path] = normalized_entries
            self._save_settings(self.settings)

        self.folderEntriesReady.emit(folder_path, normalized_entries)

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

    def _preview_source(self, path: Path, kind: str, label: str, refresh_on_open: bool) -> str:
        if kind == "file" and path.suffix.lower() in IMAGE_EXTENSIONS:
            thumb_uri = self._thumb_cache.get_thumbnail_uri(path, refresh=refresh_on_open, size=(120, 120))
            if thumb_uri:
                return thumb_uri
        return self.iconDataUrl(str(path), kind, label)

    def _path_exists(self, path: str) -> bool:
        if not path:
            return True
        try:
            return Path(path).exists()
        except OSError:
            return False

    def _refresh_ring_items(self, force: bool = False) -> bool:
        if not force and not self.settings.automatic_icon_refresh:
            return False

        original_count = len(self.settings.items)
        self.settings.items = [
            item
            for item in self.settings.items
            if not item.path or self._path_exists(item.path)
        ]
        changed = len(self.settings.items) != original_count
        if changed:
            valid_folder_paths = {
                item.path
                for item in self.settings.items
                if item.kind == "folder" and item.path
            }
            self.settings.folder_cache = {
                path: entries
                for path, entries in self.settings.folder_cache.items()
                if path in valid_folder_paths
            }
        return changed

    def _build_folder_entries(self, folder: Path, refresh_on_open: bool) -> list[dict[str, str]]:
        entries: list[dict[str, str]] = []
        children = sorted(
            folder.iterdir(),
            key=lambda path: (not path.is_dir(), path.name.lower()),
        )
        for child in children[:200]:
            child_kind = self._kind_for_path(child)
            label = child.name
            entries.append(
                {
                    "path": str(child),
                    "label": label,
                    "kind": child_kind,
                    "icon": "",
                }
            )
        return entries

    def _refresh_folder_cache(self, force: bool = False) -> bool:
        if not force and not self.settings.automatic_folder_refresh:
            return False

        changed = False
        next_cache: dict[str, list[dict[str, str]]] = {}
        for item in self.settings.items:
            if item.kind != "folder" or not item.path:
                continue
            folder = Path(item.path)
            if not folder.exists() or not folder.is_dir():
                continue
            try:
                entries = self._build_folder_entries(folder, refresh_on_open=True)
            except OSError:
                continue
            cached_entries = self.settings.folder_cache.get(item.path, [])
            if cached_entries != entries:
                changed = True
            next_cache[item.path] = entries

        if self.settings.folder_cache != next_cache:
            self.settings.folder_cache = next_cache
            changed = True
        return changed

    @Slot()
    def refreshEnabledData(self) -> None:
        ring_changed = self._refresh_ring_items()
        folder_changed = self._refresh_folder_cache()
        if ring_changed or folder_changed:
            self._save_settings(self.settings)
        if ring_changed:
            self.ringItemsChanged.emit()

    @Slot()
    def manualRefreshEnabled(self) -> None:
        ring_changed = False
        folder_changed = False

        if not self.settings.automatic_icon_refresh:
            ring_changed = self._refresh_ring_items(force=True)
        if not self.settings.automatic_folder_refresh:
            folder_changed = self._refresh_folder_cache(force=True)

        if ring_changed or folder_changed:
            self._save_settings(self.settings)
        if ring_changed:
            self.ringItemsChanged.emit()

    @Slot(str, result=bool)
    def openPath(self, path: str) -> bool:
        if not path:
            return False
        return open_path(path)

    @Slot(str, bool, result="QVariantList")
    def listFolderEntries(self, folder_path: str, refresh_on_open: bool) -> list[dict[str, str]]:
        folder = Path(folder_path)
        if not self.settings.automatic_folder_refresh:
            return self.settings.folder_cache.get(folder_path, [])

        if not folder.exists() or not folder.is_dir():
            return []

        try:
            entries = self._build_folder_entries(folder, refresh_on_open=refresh_on_open)
        except OSError:
            return []

        if self.settings.folder_cache.get(folder_path) != entries:
            self.settings.folder_cache[folder_path] = entries
            self._save_settings(self.settings)
        return entries

    hotkey = Property(
        str,
        get_hotkey,
        set_hotkey,
        notify=hotkeyChanged,
    )

    startupMessageEnabled = Property(
        bool,
        get_startup_message_enabled,
        set_startup_message_enabled,
        notify=startupMessageEnabledChanged,
    )

    automaticIconRefresh = Property(
        bool,
        get_automatic_icon_refresh,
        set_automatic_icon_refresh,
        notify=automaticIconRefreshChanged,
    )

    automaticFolderRefresh = Property(
        bool,
        get_automatic_folder_refresh,
        set_automatic_folder_refresh,
        notify=automaticFolderRefreshChanged,
    )

    closeAfterLaunch = Property(
        bool,
        get_close_after_launch,
        set_close_after_launch,
        notify=closeAfterLaunchChanged,
    )

    ringItems = Property(
        "QVariantList",
        get_ring_items,
        notify=ringItemsChanged,
    )

    animationSpeedScale = Property(
        float,
        get_animation_speed_scale,
        set_animation_speed_scale,
        notify=animationSpeedScaleChanged,
    )

    animationsEnabled = Property(
        bool,
        get_animations_enabled,
        set_animations_enabled,
        notify=animationsEnabledChanged,
    )

    folderCompactThreshold = Property(
        int,
        get_folder_compact_threshold,
        set_folder_compact_threshold,
        notify=folderCompactThresholdChanged,
    )

    previewVersion = Property(
        int,
        get_preview_version,
        notify=previewVersionChanged,
    )

    appVersion = Property(
        str,
        get_app_version,
        constant=True,
    )
