from __future__ import annotations

import configparser
import ctypes
import json
import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from ctypes import wintypes
from dataclasses import asdict, dataclass, field
from datetime import datetime
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
from PySide6.QtGui import QColor, QIcon, QImage, QPainter, QPixmap
from PySide6.QtWidgets import QFileIconProvider

from radialdock.cache import ThumbnailCache
from radialdock.shell_open import open_path

try:
    import pythoncom
    from win32com.client import Dispatch
except ImportError:  # pragma: no cover - dependency is part of requirements on Windows
    pythoncom = None
    Dispatch = None


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
EXPORT_FILE_VERSION = 1

SHGFI_ICON = 0x000000100
SHGFI_LARGEICON = 0x000000000


class SHFILEINFOW(ctypes.Structure):
    _fields_ = [
        ("hIcon", wintypes.HICON),
        ("iIcon", ctypes.c_int),
        ("dwAttributes", wintypes.DWORD),
        ("szDisplayName", wintypes.WCHAR * 260),
        ("szTypeName", wintypes.WCHAR * 80),
    ]


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
    angle: float = 0.0
    children: list["DockItem"] = field(default_factory=list)


def default_ring_items() -> list[DockItem]:
    return []


@dataclass
class Settings:
    hotkey: str = "Ctrl+Space"
    startup_message_enabled: bool = True
    automatic_icon_refresh: bool = True
    automatic_folder_refresh: bool = True
    close_after_launch: bool = DEFAULT_CLOSE_AFTER_LAUNCH
    automatic_item_alignment: bool = True
    show_file_extensions: bool = False
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
    automaticItemAlignmentChanged = Signal()
    showFileExtensionsChanged = Signal()
    folderRefreshStateChanged = Signal(str, str)
    folderEntriesReady = Signal(str, "QVariantList")
    _folderEntriesResolved = Signal(str, object)
    _refreshResolved = Signal(int, object, object, bool)
    _iconResolved = Signal(str, str)
    previewVersionChanged = Signal()
    ringItemsChanged = Signal()
    animationSpeedScaleChanged = Signal()
    animationsEnabledChanged = Signal()
    folderCompactThresholdChanged = Signal()

    def __init__(self, paths: AppPaths) -> None:
        super().__init__()
        self.paths = paths
        self._settings_revision = 0
        self._refresh_pending = False
        self.settings = self._load_settings()
        self._icon_provider = QFileIconProvider()
        self._thumb_cache = ThumbnailCache(paths.cache_dir)
        self._icon_cache: dict[str, str] = {}
        self._preview_version = 0
        self._preview_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="radialdock-preview")
        self._pending_previews: set[tuple[str, tuple[int, int]]] = set()
        self._pending_folder_requests: set[str] = set()
        self._pending_icon_requests: set[str] = set()
        self._folder_refresh_states: dict[str, str] = {}
        self._preview_lock = threading.Lock()
        self._folderEntriesResolved.connect(
            self._handle_folder_entries_resolved,
            Qt.ConnectionType.QueuedConnection,
        )
        self._refreshResolved.connect(
            self._handle_refresh_resolved,
            Qt.ConnectionType.QueuedConnection,
        )
        self._iconResolved.connect(
            self._handle_icon_resolved,
            Qt.ConnectionType.QueuedConnection,
        )
        self._app_version = resolve_app_version()
        self._sync_folder_refresh_state_map(self.settings.items, emit=False)

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
                self._dock_item_from_raw(item, index)
                for index, item in enumerate(raw.get("items", []))
                if isinstance(item, dict)
            ]
            return Settings(
                hotkey=raw.get("hotkey", "Ctrl+Space"),
                startup_message_enabled=bool(raw.get("startup_message_enabled", True)),
                automatic_icon_refresh=bool(raw.get("automatic_icon_refresh", True)),
                automatic_folder_refresh=bool(
                    raw.get("automatic_folder_refresh", raw.get("refresh_on_open", True))
                ),
                close_after_launch=bool(raw.get("close_after_launch", DEFAULT_CLOSE_AFTER_LAUNCH)),
                automatic_item_alignment=bool(raw.get("automatic_item_alignment", True)),
                show_file_extensions=bool(raw.get("show_file_extensions", False)),
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
        self._settings_revision += 1
        self.paths.config_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    def _emit_all_settings_changed(self, ring_changed: bool) -> None:
        self.hotkeyChanged.emit()
        self.startupMessageEnabledChanged.emit()
        self.automaticIconRefreshChanged.emit()
        self.automaticFolderRefreshChanged.emit()
        self.closeAfterLaunchChanged.emit()
        self.automaticItemAlignmentChanged.emit()
        self.showFileExtensionsChanged.emit()
        self.animationSpeedScaleChanged.emit()
        self.animationsEnabledChanged.emit()
        self.folderCompactThresholdChanged.emit()
        if ring_changed:
            self.ringItemsChanged.emit()

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

    def _default_folder_refresh_state(self) -> str:
        return "pending" if self.settings.automatic_folder_refresh else "disabled"

    def _set_folder_refresh_state(self, folder_path: str, state: str, emit: bool = True) -> None:
        if not folder_path:
            return

        previous = self._folder_refresh_states.get(folder_path)
        if previous == state:
            return

        self._folder_refresh_states[folder_path] = state
        if emit:
            self.folderRefreshStateChanged.emit(folder_path, state)

    def _remove_folder_refresh_state(self, folder_path: str, emit: bool = True) -> None:
        if folder_path not in self._folder_refresh_states:
            return

        self._folder_refresh_states.pop(folder_path, None)
        if emit:
            self.folderRefreshStateChanged.emit(folder_path, "")

    def _sync_folder_refresh_state_map(self, items: list[DockItem], emit: bool = True) -> None:
        current_paths = self._collect_folder_paths(items)
        existing_paths = set(self._folder_refresh_states.keys())

        for removed_path in existing_paths - current_paths:
            self._remove_folder_refresh_state(removed_path, emit=emit)

        default_state = self._default_folder_refresh_state()
        for folder_path in current_paths:
            current_state = self._folder_refresh_states.get(folder_path)
            if current_state is None:
                self._set_folder_refresh_state(folder_path, default_state, emit=emit)
            elif default_state == "disabled" and current_state != "disabled":
                self._set_folder_refresh_state(folder_path, "disabled", emit=emit)
            elif default_state == "pending" and current_state == "disabled":
                self._set_folder_refresh_state(folder_path, "pending", emit=emit)

    def _color_for_item(self, path: str, label: str, index: int) -> str:
        seed = path or label or str(index)
        value = sum(ord(char) for char in seed)
        return DEFAULT_ITEM_COLORS[value % len(DEFAULT_ITEM_COLORS)]

    def _dock_item_from_raw(self, raw_item: dict[str, object], index: int) -> DockItem:
        path = str(raw_item.get("path", ""))
        label = str(raw_item.get("label", ""))
        kind = str(raw_item.get("kind", "file") or "file")
        color = str(raw_item.get("color", "")).strip()
        if not label:
            label = Path(path).name if path else "Item"
        if not color:
            color = self._color_for_item(path, label, index)

        raw_children = raw_item.get("children", [])
        children: list[DockItem] = []
        if isinstance(raw_children, list):
            for child_index, raw_child in enumerate(raw_children):
                if not isinstance(raw_child, dict):
                    continue
                children.append(self._dock_item_from_raw(raw_child, child_index))

        return DockItem(
            path=path,
            label=label,
            kind=kind,
            color=color,
            angle=float(raw_item.get("angle", 0.0) or 0.0),
            children=children,
        )

    def _serialize_dock_item(self, item: DockItem) -> dict[str, object]:
        payload: dict[str, object] = {
            "path": item.path,
            "label": item.label,
            "kind": item.kind,
            "color": item.color,
            "angle": item.angle,
        }
        if item.children:
            payload["children"] = [self._serialize_dock_item(child) for child in item.children]
        return payload

    def _kind_for_path(self, candidate: Path) -> str:
        if candidate.is_dir():
            return "folder"
        if candidate.suffix.lower() in {".lnk", ".url"}:
            return "shortcut"
        return "file"

    @Slot(str, result=str)
    def pathKind(self, path: str) -> str:
        if not path:
            return "file"
        candidate = Path(path)
        if not candidate.exists():
            if candidate.suffix.lower() in {".lnk", ".url"}:
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
        self._sync_folder_refresh_state_map(self.settings.items)
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

    def get_automatic_item_alignment(self) -> bool:
        return self.settings.automatic_item_alignment

    def set_automatic_item_alignment(self, value: bool) -> None:
        normalized = bool(value)
        if self.settings.automatic_item_alignment == normalized:
            return
        self.settings.automatic_item_alignment = normalized
        self._save_settings(self.settings)
        self.automaticItemAlignmentChanged.emit()

    def get_show_file_extensions(self) -> bool:
        return self.settings.show_file_extensions

    def set_show_file_extensions(self, value: bool) -> None:
        normalized = bool(value)
        if self.settings.show_file_extensions == normalized:
            return
        self.settings.show_file_extensions = normalized
        self._save_settings(self.settings)
        self.showFileExtensionsChanged.emit()

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

    def get_ring_items(self) -> list[dict[str, object]]:
        return [self._serialize_dock_item(item) for item in self.settings.items]

    @Slot("QVariantList")
    def saveRingItems(self, items: list[object]) -> None:
        parsed_items: list[DockItem] = []
        for index, raw_item in enumerate(items):
            if not isinstance(raw_item, dict):
                continue
            parsed_items.append(self._dock_item_from_raw(raw_item, index))

        self.settings.items = parsed_items
        self._save_settings(self.settings)
        self._sync_folder_refresh_state_map(self.settings.items)
        self.ringItemsChanged.emit()

    @Slot()
    def clearRingItems(self) -> None:
        self.settings.items = []
        self.settings.folder_cache = {}
        self._save_settings(self.settings)
        self._sync_folder_refresh_state_map(self.settings.items)
        self.ringItemsChanged.emit()

    @Slot()
    def resetQuickSettings(self) -> None:
        self.settings.startup_message_enabled = True
        self.settings.automatic_icon_refresh = True
        self.settings.automatic_folder_refresh = True
        self.settings.close_after_launch = DEFAULT_CLOSE_AFTER_LAUNCH
        self.settings.automatic_item_alignment = True
        self.settings.show_file_extensions = False
        self.settings.hotkey = "Ctrl+Space"
        self.settings.animation_speed_scale = DEFAULT_ANIMATION_SPEED_SCALE
        self.settings.animations_enabled = DEFAULT_ANIMATIONS_ENABLED
        self.settings.folder_compact_threshold = DEFAULT_FOLDER_COMPACT_THRESHOLD
        self._save_settings(self.settings)
        self._sync_folder_refresh_state_map(self.settings.items)
        self.hotkeyChanged.emit()
        self.startupMessageEnabledChanged.emit()
        self.automaticIconRefreshChanged.emit()
        self.automaticFolderRefreshChanged.emit()
        self.closeAfterLaunchChanged.emit()
        self.automaticItemAlignmentChanged.emit()
        self.showFileExtensionsChanged.emit()
        self.animationSpeedScaleChanged.emit()
        self.animationsEnabledChanged.emit()
        self.folderCompactThresholdChanged.emit()

    def export_payload(self, include_items: bool) -> dict[str, object]:
        payload: dict[str, object] = {
            "format": "radialdock-export",
            "export_version": EXPORT_FILE_VERSION,
            "exported_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
            "settings": {
                "hotkey": self.settings.hotkey,
                "startup_message_enabled": self.settings.startup_message_enabled,
                "automatic_icon_refresh": self.settings.automatic_icon_refresh,
                "automatic_folder_refresh": self.settings.automatic_folder_refresh,
                "close_after_launch": self.settings.close_after_launch,
                "automatic_item_alignment": self.settings.automatic_item_alignment,
                "show_file_extensions": self.settings.show_file_extensions,
                "animation_speed_scale": self.settings.animation_speed_scale,
                "animations_enabled": self.settings.animations_enabled,
                "folder_compact_threshold": self.settings.folder_compact_threshold,
            },
            "includes_items": bool(include_items),
        }
        if include_items:
            payload["items"] = self.get_ring_items()
        return payload

    def import_payload(self, payload: object) -> tuple[bool, str]:
        if not isinstance(payload, dict):
            return False, "Invalid backup file."

        if str(payload.get("format", "")) != "radialdock-export":
            return False, "This file is not a RadialDock export."

        settings_payload = payload.get("settings")
        if not isinstance(settings_payload, dict):
            return False, "The export file is missing settings data."

        imported_hotkey = str(settings_payload.get("hotkey", self.settings.hotkey)).strip() or "Ctrl+Space"
        self.settings.hotkey = imported_hotkey
        self.settings.startup_message_enabled = bool(
            settings_payload.get("startup_message_enabled", self.settings.startup_message_enabled)
        )
        self.settings.automatic_icon_refresh = bool(
            settings_payload.get("automatic_icon_refresh", self.settings.automatic_icon_refresh)
        )
        self.settings.automatic_folder_refresh = bool(
            settings_payload.get("automatic_folder_refresh", self.settings.automatic_folder_refresh)
        )
        self.settings.close_after_launch = bool(
            settings_payload.get("close_after_launch", self.settings.close_after_launch)
        )
        self.settings.automatic_item_alignment = bool(
            settings_payload.get("automatic_item_alignment", self.settings.automatic_item_alignment)
        )
        self.settings.show_file_extensions = bool(
            settings_payload.get("show_file_extensions", self.settings.show_file_extensions)
        )
        self.settings.animation_speed_scale = self._sanitize_animation_speed(
            settings_payload.get("animation_speed_scale", self.settings.animation_speed_scale)
        )
        self.settings.animations_enabled = bool(
            settings_payload.get("animations_enabled", self.settings.animations_enabled)
        )
        self.settings.folder_compact_threshold = self._sanitize_compact_threshold(
            settings_payload.get("folder_compact_threshold", self.settings.folder_compact_threshold)
        )

        ring_changed = False
        if bool(payload.get("includes_items", False)):
            raw_items = payload.get("items", [])
            if not isinstance(raw_items, list):
                return False, "The export file has invalid dock items."
            self.settings.items = [
                self._dock_item_from_raw(raw_item, index)
                for index, raw_item in enumerate(raw_items)
                if isinstance(raw_item, dict)
            ]
            self.settings.folder_cache = {}
            ring_changed = True

        self._icon_cache.clear()
        self._save_settings(self.settings)
        self._sync_folder_refresh_state_map(self.settings.items)
        self._emit_all_settings_changed(ring_changed=ring_changed)
        QMetaObject.invokeMethod(self, "_bump_preview_version", Qt.ConnectionType.QueuedConnection)

        if ring_changed:
            return True, "Settings and dock items imported."
        return True, "Settings imported."

    @Slot(str, str, str, result=str)
    def displayLabel(self, label: str, path: str, kind: str) -> str:
        text = str(label or "").strip()
        normalized_kind = str(kind or "file").lower()
        if not text:
            text = Path(path).name if path else "Item"

        if self.settings.show_file_extensions:
            return text

        if normalized_kind in {"folder", "group"}:
            return text

        try:
            suffix = Path(path).suffix
        except (TypeError, ValueError):
            suffix = ""

        if not suffix:
            return text

        if text.lower().endswith(suffix.lower()):
            trimmed = text[: -len(suffix)].rstrip()
            return trimmed or text
        return text

    @Slot(str, result="QVariantList")
    def cachedFolderEntries(self, folder_path: str) -> list[dict[str, str]]:
        cached_entries = self.settings.folder_cache.get(folder_path, [])
        return [dict(entry) for entry in cached_entries]

    @Slot(str, result=str)
    def folderRefreshState(self, folder_path: str) -> str:
        if not folder_path:
            return ""
        return self._folder_refresh_states.get(folder_path, self._default_folder_refresh_state())

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

        placeholder = self._fallback_data_url(label)
        self._icon_cache[cache_key] = placeholder
        if path:
            self._queue_icon_generation(path, kind, label, cache_key)
        return placeholder

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

    def _queue_icon_generation(self, path: str, kind: str, label: str, cache_key: str) -> None:
        with self._preview_lock:
            if cache_key in self._pending_icon_requests:
                return
            self._pending_icon_requests.add(cache_key)

        def worker() -> None:
            try:
                data_url = self._resolve_icon_data_url(path, kind)
                if data_url:
                    self._iconResolved.emit(cache_key, data_url)
            finally:
                with self._preview_lock:
                    self._pending_icon_requests.discard(cache_key)

        self._preview_executor.submit(worker)

    @Slot(str, str)
    def _handle_icon_resolved(self, cache_key: str, data_url: str) -> None:
        if not cache_key or not data_url:
            return
        self._icon_cache[cache_key] = data_url
        self._bump_preview_version()

    @Slot(str, bool)
    def requestFolderEntries(self, folder_path: str, refresh_on_open: bool) -> None:
        if not folder_path:
            self.folderEntriesReady.emit("", [])
            return

        if not self.settings.automatic_folder_refresh:
            self._set_folder_refresh_state(folder_path, "disabled")
            self.folderEntriesReady.emit(folder_path, self.settings.folder_cache.get(folder_path, []))
            return

        self._set_folder_refresh_state(folder_path, "checking")

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

        self._set_folder_refresh_state(folder_path, "checked")
        self.folderEntriesReady.emit(folder_path, normalized_entries)

    def _resolve_icon_data_url(self, path: str, kind: str) -> str:
        normalized_kind = (kind or "").lower()
        suffix = Path(path).suffix.lower() if path else ""

        if path and (normalized_kind == "shortcut" or suffix in {".lnk", ".url"}):
            shortcut_data = self._shortcut_icon_data_url(path)
            if shortcut_data:
                return shortcut_data

        if path:
            shell_data = self._shell_icon_data_url_for_path(path)
            if shell_data:
                return shell_data

        return ""

    def _shortcut_icon_data_url(self, shortcut_path: str) -> str:
        suffix = Path(shortcut_path).suffix.lower()
        if suffix == ".url":
            return self._url_shortcut_icon_data_url(shortcut_path)

        icon_path, icon_index, target_path = self._read_shortcut_metadata(shortcut_path)

        if icon_path:
            custom_icon = self._icon_location_data_url(icon_path, icon_index)
            if custom_icon:
                return custom_icon

        if target_path:
            target_icon = self._shell_icon_data_url_for_path(target_path)
            if target_icon:
                return target_icon

        return self._shell_icon_data_url_for_path(shortcut_path)

    def _url_shortcut_icon_data_url(self, url_path: str) -> str:
        icon_path, icon_index = self._read_url_shortcut_metadata(url_path)

        if icon_path:
            custom_icon = self._icon_location_data_url(icon_path, icon_index)
            if custom_icon:
                return custom_icon

        return self._shell_icon_data_url_for_path(url_path)

    def _icon_for_item(self, path: str, kind: str) -> QIcon:
        normalized_kind = (kind or "").lower()
        suffix = Path(path).suffix.lower() if path else ""

        if path and (normalized_kind == "shortcut" or suffix in {".lnk", ".url"}):
            shortcut_icon = self._shortcut_icon(path)
            if not shortcut_icon.isNull():
                return shortcut_icon

        if path:
            file_info = QFileInfo(path)
            if file_info.exists():
                return self._icon_provider.icon(file_info)

        if normalized_kind == "folder":
            return self._icon_provider.icon(QFileIconProvider.IconType.Folder)
        return self._icon_provider.icon(QFileIconProvider.IconType.File)

    def _shortcut_icon(self, shortcut_path: str) -> QIcon:
        suffix = Path(shortcut_path).suffix.lower()
        if suffix == ".url":
            return self._url_shortcut_icon(shortcut_path)

        icon_path, icon_index, target_path = self._read_shortcut_metadata(shortcut_path)

        if icon_path:
            custom_icon = self._icon_from_icon_location(icon_path, icon_index)
            if not custom_icon.isNull():
                return custom_icon

        if target_path:
            file_info = QFileInfo(target_path)
            if file_info.exists():
                target_icon = self._icon_provider.icon(file_info)
                if not target_icon.isNull():
                    return target_icon

        shell_icon = self._shell_icon_for_path(shortcut_path)
        if not shell_icon.isNull():
            return shell_icon

        return QIcon()

    def _url_shortcut_icon(self, url_path: str) -> QIcon:
        icon_path, icon_index = self._read_url_shortcut_metadata(url_path)

        if icon_path:
            custom_icon = self._icon_from_icon_location(icon_path, icon_index)
            if not custom_icon.isNull():
                return custom_icon

        shell_icon = self._shell_icon_for_path(url_path)
        if not shell_icon.isNull():
            return shell_icon

        return QIcon()

    def _read_shortcut_metadata(self, shortcut_path: str) -> tuple[str, int, str]:
        if Dispatch is None:
            return "", 0, ""

        shell = None
        shortcut = None
        if pythoncom is not None:
            pythoncom.CoInitialize()
        try:
            shell = Dispatch("WScript.Shell")
            shortcut = shell.CreateShortcut(str(shortcut_path))
            icon_location = str(getattr(shortcut, "IconLocation", "") or "")
            target_path = str(getattr(shortcut, "TargetPath", "") or "")
        except Exception:
            return "", 0, ""
        finally:
            shortcut = None
            shell = None
            if pythoncom is not None:
                pythoncom.CoUninitialize()

        icon_path = ""
        icon_index = 0
        if icon_location:
            raw_icon = os.path.expandvars(icon_location.strip().strip('"'))
            split_index = raw_icon.rfind(",")
            if split_index > 0:
                maybe_index = raw_icon[split_index + 1:].strip()
                try:
                    icon_index = int(maybe_index)
                    icon_path = raw_icon[:split_index].strip().strip('"')
                except ValueError:
                    icon_path = raw_icon
                    icon_index = 0
            else:
                icon_path = raw_icon

        return icon_path, icon_index, target_path

    def _read_url_shortcut_metadata(self, url_path: str) -> tuple[str, int]:
        parser = configparser.ConfigParser(interpolation=None, strict=False)

        for encoding in ("utf-8-sig", "utf-16", "cp1252"):
            try:
                with open(url_path, "r", encoding=encoding) as handle:
                    parser.read_file(handle)
                break
            except (OSError, UnicodeError, configparser.Error):
                parser = configparser.ConfigParser(interpolation=None, strict=False)
        else:
            return "", 0

        if not parser.has_section("InternetShortcut"):
            return "", 0

        raw_icon_path = parser.get("InternetShortcut", "IconFile", fallback="").strip().strip('"')
        raw_icon_index = parser.get("InternetShortcut", "IconIndex", fallback="0").strip()

        icon_path = os.path.expandvars(raw_icon_path) if raw_icon_path else ""
        try:
            icon_index = int(raw_icon_index)
        except ValueError:
            icon_index = 0

        return icon_path, icon_index

    def _icon_location_data_url(self, icon_path: str, icon_index: int) -> str:
        if not icon_path:
            return ""

        candidate = Path(icon_path)
        lower_path = icon_path.lower()

        if candidate.exists() and lower_path.endswith(".ico"):
            image = QImage(str(candidate))
            if not image.isNull():
                return self._qimage_to_data_url(image)

        if candidate.exists() and lower_path.endswith((".exe", ".dll", ".icl", ".cpl", ".mun")):
            extracted = self._extract_icon_resource_data_url(str(candidate), icon_index)
            if extracted:
                return extracted

        if candidate.exists():
            return self._shell_icon_data_url_for_path(str(candidate))

        return ""

    def _icon_from_icon_location(self, icon_path: str, icon_index: int) -> QIcon:
        if not icon_path:
            return QIcon()

        candidate = Path(icon_path)
        lower_path = icon_path.lower()

        if candidate.exists() and lower_path.endswith(".ico"):
            icon = QIcon(str(candidate))
            if not icon.isNull():
                return icon

        if candidate.exists() and lower_path.endswith((".exe", ".dll", ".icl", ".cpl", ".mun")):
            extracted = self._extract_icon_resource(str(candidate), icon_index)
            if not extracted.isNull():
                return extracted

        if candidate.exists():
            shell_icon = self._shell_icon_for_path(str(candidate))
            if not shell_icon.isNull():
                return shell_icon

        return QIcon()

    def _extract_icon_resource_data_url(self, icon_path: str, icon_index: int) -> str:
        large_icons = (wintypes.HICON * 1)()
        small_icons = (wintypes.HICON * 1)()
        extracted = ctypes.windll.shell32.ExtractIconExW(
            icon_path,
            icon_index,
            large_icons,
            small_icons,
            1,
        )
        if extracted <= 0:
            return ""

        handles = [handle for handle in (large_icons[0], small_icons[0]) if handle]
        if not handles:
            return ""

        try:
            return self._hicon_to_data_url(handles[0])
        finally:
            for handle in handles:
                ctypes.windll.user32.DestroyIcon(handle)

    def _extract_icon_resource(self, icon_path: str, icon_index: int) -> QIcon:
        large_icons = (wintypes.HICON * 1)()
        small_icons = (wintypes.HICON * 1)()
        extracted = ctypes.windll.shell32.ExtractIconExW(
            icon_path,
            icon_index,
            large_icons,
            small_icons,
            1,
        )
        if extracted <= 0:
            return QIcon()

        handles = [handle for handle in (large_icons[0], small_icons[0]) if handle]
        if not handles:
            return QIcon()

        try:
            image = QImage.fromHICON(handles[0])
            if image.isNull():
                return QIcon()
            pixmap = QPixmap.fromImage(image)
            if pixmap.isNull():
                return QIcon()
            return QIcon(pixmap)
        finally:
            for handle in handles:
                ctypes.windll.user32.DestroyIcon(handle)

    def _shell_icon_for_path(self, path: str) -> QIcon:
        if not path:
            return QIcon()

        file_info = SHFILEINFOW()
        result = ctypes.windll.shell32.SHGetFileInfoW(
            str(path),
            0,
            ctypes.byref(file_info),
            ctypes.sizeof(file_info),
            SHGFI_ICON | SHGFI_LARGEICON,
        )
        if not result or not file_info.hIcon:
            return QIcon()

        try:
            image = QImage.fromHICON(file_info.hIcon)
            if image.isNull():
                return QIcon()
            pixmap = QPixmap.fromImage(image)
            if pixmap.isNull():
                return QIcon()
            return QIcon(pixmap)
        finally:
            ctypes.windll.user32.DestroyIcon(file_info.hIcon)

    def _shell_icon_data_url_for_path(self, path: str) -> str:
        if not path:
            return ""

        file_info = SHFILEINFOW()
        result = ctypes.windll.shell32.SHGetFileInfoW(
            str(path),
            0,
            ctypes.byref(file_info),
            ctypes.sizeof(file_info),
            SHGFI_ICON | SHGFI_LARGEICON,
        )
        if not result or not file_info.hIcon:
            return ""

        try:
            return self._hicon_to_data_url(file_info.hIcon)
        finally:
            ctypes.windll.user32.DestroyIcon(file_info.hIcon)

    def _pixmap_to_data_url(self, pixmap: QPixmap) -> str:
        payload = QByteArray()
        buffer = QBuffer(payload)
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        pixmap.save(buffer, "PNG")
        encoded = bytes(payload.toBase64()).decode("ascii")
        return f"data:image/png;base64,{encoded}"

    def _qimage_to_data_url(self, image: QImage) -> str:
        payload = QByteArray()
        buffer = QBuffer(payload)
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        image.save(buffer, "PNG")
        encoded = bytes(payload.toBase64()).decode("ascii")
        return f"data:image/png;base64,{encoded}"

    def _hicon_to_data_url(self, icon_handle: wintypes.HICON) -> str:
        if not icon_handle:
            return ""

        image = QImage.fromHICON(icon_handle)
        if image.isNull():
            return ""
        return self._qimage_to_data_url(image)

    def _fallback_pixmap(self, label: str) -> QPixmap:
        pixmap = QPixmap(64, 64)
        pixmap.fill(QColor("#2D4054"))

        painter = QPainter(pixmap)
        painter.setPen(QColor("#EAF4FF"))
        painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, (label[:1] or "?").upper())
        painter.end()
        return pixmap

    def _fallback_data_url(self, label: str) -> str:
        return self._pixmap_to_data_url(self._fallback_pixmap(label))

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

        self.settings.items, changed = self._refresh_item_tree(self.settings.items)
        if changed:
            valid_folder_paths = self._collect_folder_paths(self.settings.items)
            self.settings.folder_cache = {
                path: entries
                for path, entries in self.settings.folder_cache.items()
                if path in valid_folder_paths
            }
        return changed

    def _clone_items(self) -> list[DockItem]:
        return [self._clone_dock_item(item) for item in self.settings.items]

    def _clone_dock_item(self, item: DockItem) -> DockItem:
        return DockItem(
            path=item.path,
            label=item.label,
            kind=item.kind,
            color=item.color,
            angle=item.angle,
            children=[self._clone_dock_item(child) for child in item.children],
        )

    def _clone_folder_cache(self) -> dict[str, list[dict[str, str]]]:
        return {
            folder_path: [dict(entry) for entry in entries]
            for folder_path, entries in self.settings.folder_cache.items()
        }

    def _refresh_ring_items_snapshot(
        self,
        items: list[DockItem],
        folder_cache: dict[str, list[dict[str, str]]],
        enabled: bool,
    ) -> tuple[list[DockItem], dict[str, list[dict[str, str]]], bool]:
        if not enabled:
            return items, folder_cache, False

        next_items, changed = self._refresh_item_tree(items)
        next_cache = folder_cache
        if changed:
            valid_folder_paths = self._collect_folder_paths(next_items)
            next_cache = {
                path: entries
                for path, entries in folder_cache.items()
                if path in valid_folder_paths
            }
        return next_items, next_cache, changed

    def _refresh_item_tree(self, items: list[DockItem]) -> tuple[list[DockItem], bool]:
        next_items: list[DockItem] = []
        changed = False

        for item in items:
            normalized_items, item_changed = self._refresh_single_item(item)
            if item_changed:
                changed = True
            next_items.extend(normalized_items)

        if not changed and len(next_items) != len(items):
            changed = True
        return next_items, changed

    def _refresh_single_item(self, item: DockItem) -> tuple[list[DockItem], bool]:
        if item.kind == "group":
            next_children, child_changed = self._refresh_item_tree(item.children)
            if not next_children:
                return [], True
            if len(next_children) == 1:
                return [next_children[0]], True

            group_changed = child_changed or len(next_children) != len(item.children)
            normalized_group = DockItem(
                path="",
                label=item.label or "Group",
                kind="group",
                color=item.color,
                angle=item.angle,
                children=next_children,
            )
            return [normalized_group], group_changed

        if item.path and not self._path_exists(item.path):
            return [], True
        return [self._clone_dock_item(item)], False

    def _collect_folder_paths(self, items: list[DockItem]) -> set[str]:
        folder_paths: set[str] = set()
        for item in items:
            if item.kind == "folder" and item.path:
                folder_paths.add(item.path)
            if item.children:
                folder_paths.update(self._collect_folder_paths(item.children))
        return folder_paths

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
        for folder_path in sorted(self._collect_folder_paths(self.settings.items)):
            folder = Path(folder_path)
            if not folder.exists() or not folder.is_dir():
                continue
            try:
                entries = self._build_folder_entries(folder, refresh_on_open=True)
            except OSError:
                continue
            cached_entries = self.settings.folder_cache.get(folder_path, [])
            if cached_entries != entries:
                changed = True
            next_cache[folder_path] = entries

        if self.settings.folder_cache != next_cache:
            self.settings.folder_cache = next_cache
            changed = True
        return changed

    def _refresh_folder_cache_snapshot(
        self,
        items: list[DockItem],
        folder_cache: dict[str, list[dict[str, str]]],
        enabled: bool,
    ) -> tuple[dict[str, list[dict[str, str]]], bool]:
        if not enabled:
            return folder_cache, False

        changed = False
        next_cache: dict[str, list[dict[str, str]]] = {}
        for folder_path in sorted(self._collect_folder_paths(items)):
            folder = Path(folder_path)
            if not folder.exists() or not folder.is_dir():
                continue
            try:
                entries = self._build_folder_entries(folder, refresh_on_open=True)
            except OSError:
                continue
            cached_entries = folder_cache.get(folder_path, [])
            if cached_entries != entries:
                changed = True
            next_cache[folder_path] = entries

        if next_cache != folder_cache:
            changed = True
        return next_cache, changed

    @Slot(int, object, object, bool)
    def _handle_refresh_resolved(
        self,
        revision: int,
        next_items_obj: object,
        next_cache_obj: object,
        ring_changed: bool,
    ) -> None:
        self._refresh_pending = False

        if revision != self._settings_revision:
            return

        next_items = next_items_obj if isinstance(next_items_obj, list) else []
        next_cache = next_cache_obj if isinstance(next_cache_obj, dict) else {}
        folder_changed = self.settings.folder_cache != next_cache
        self._sync_folder_refresh_state_map(next_items)
        if self.settings.automatic_folder_refresh:
            for folder_path in self._collect_folder_paths(next_items):
                if folder_path in next_cache:
                    self._set_folder_refresh_state(folder_path, "checked")

        if not ring_changed and not folder_changed:
            return

        self.settings.items = next_items
        self.settings.folder_cache = next_cache
        self._save_settings(self.settings)
        if folder_changed:
            for folder_path, entries in next_cache.items():
                self.folderEntriesReady.emit(folder_path, entries)
        if ring_changed:
            self.ringItemsChanged.emit()

    @Slot()
    def refreshEnabledData(self) -> None:
        if self._refresh_pending:
            return

        items_snapshot = self._clone_items()
        folder_cache_snapshot = self._clone_folder_cache()
        revision = self._settings_revision
        icon_refresh_enabled = self.settings.automatic_icon_refresh
        folder_refresh_enabled = self.settings.automatic_folder_refresh
        if folder_refresh_enabled:
            for folder_path in self._collect_folder_paths(items_snapshot):
                self._set_folder_refresh_state(folder_path, "checking")
        self._refresh_pending = True

        def worker() -> None:
            next_items, next_cache, ring_changed = self._refresh_ring_items_snapshot(
                items_snapshot,
                folder_cache_snapshot,
                icon_refresh_enabled,
            )
            next_cache, _ = self._refresh_folder_cache_snapshot(
                next_items,
                next_cache,
                folder_refresh_enabled,
            )
            self._refreshResolved.emit(revision, next_items, next_cache, ring_changed)

        self._preview_executor.submit(worker)

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

    @Slot()
    def warmStartupCaches(self) -> None:
        # Warm icon provider and in-memory icon cache while the app is hidden,
        # so the first hotkey open does less work on the visible path.
        for item in self._flatten_items(self.settings.items)[:24]:
            try:
                self.iconDataUrl(item.path, item.kind, item.label)
            except Exception:
                continue

        if not self.settings.automatic_folder_refresh:
            return

        if self._refresh_pending:
            return

        items_snapshot = self._clone_items()
        folder_cache_snapshot = self._clone_folder_cache()
        revision = self._settings_revision
        for folder_path in self._collect_folder_paths(items_snapshot):
            self._set_folder_refresh_state(folder_path, "checking")
        self._refresh_pending = True

        def worker() -> None:
            next_cache, _ = self._refresh_folder_cache_snapshot(
                items_snapshot,
                folder_cache_snapshot,
                True,
            )
            self._refreshResolved.emit(revision, items_snapshot, next_cache, False)

        self._preview_executor.submit(worker)

    def _flatten_items(self, items: list[DockItem]) -> list[DockItem]:
        flattened: list[DockItem] = []
        for item in items:
            if item.kind == "group":
                flattened.extend(self._flatten_items(item.children))
            else:
                flattened.append(item)
        return flattened

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

    automaticItemAlignment = Property(
        bool,
        get_automatic_item_alignment,
        set_automatic_item_alignment,
        notify=automaticItemAlignmentChanged,
    )

    showFileExtensions = Property(
        bool,
        get_show_file_extensions,
        set_show_file_extensions,
        notify=showFileExtensionsChanged,
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
