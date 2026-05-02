"""
Windows shell Recent Items directory (Known Folder Recent).

Lists *.lnk files sorted by shortcut mtime (best-effort). Shell-only shortcut targets may
appear as kind `shortcut` using the .lnk path — see model._build_recent_folder_entries.

Limitation: edge shortcuts valid in Explorer may be omitted if they cannot be represented
as a resolved filesystem target or .lnk fallback.
"""

from __future__ import annotations

import ctypes
import os
import uuid
from ctypes import wintypes
from pathlib import Path

RECENT_MAX_ITEMS = 10

_FOLDERID_RECENT_UUID = uuid.UUID("{a75d392e-1fc7-4fbd-a90d-85e889d9479e}")

KF_FLAG_DEFAULT = 0

CSIDL_RECENT = 8
_MAX_PATH = 260


class _GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]


def _uuid_to_guid(value: uuid.UUID) -> _GUID:
    b = value.bytes_le
    return _GUID(
        int.from_bytes(b[0:4], "little"),
        int.from_bytes(b[4:6], "little"),
        int.from_bytes(b[6:8], "little"),
        (ctypes.c_ubyte * 8)(*b[8:16]),
    )


def _fallback_recent_dir() -> Path:
    return Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming"))) / (
        "Microsoft",
        "Windows",
        "Recent",
    )


def _recent_via_shgetknownfolderpath() -> Path | None:
    try:
        shell32 = ctypes.windll.shell32  # type: ignore[attr-defined]
        ole32 = ctypes.windll.ole32  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        return None

    rfid = _uuid_to_guid(_FOLDERID_RECENT_UUID)
    path_ptr = ctypes.c_wchar_p()
    raw = ""
    try:
        SHGetKnownFolderPath = shell32.SHGetKnownFolderPath
        SHGetKnownFolderPath.argtypes = [
            ctypes.POINTER(_GUID),
            wintypes.DWORD,
            wintypes.HANDLE,
            ctypes.POINTER(ctypes.c_wchar_p),
        ]
        SHGetKnownFolderPath.restype = ctypes.c_int32
        hr = SHGetKnownFolderPath(ctypes.byref(rfid), KF_FLAG_DEFAULT, None, ctypes.byref(path_ptr))
        if hr == 0 and path_ptr.value:
            raw = path_ptr.value.strip()
    finally:
        if path_ptr.value:
            ole32.CoTaskMemFree(path_ptr)

    if not raw:
        return None
    try:
        return Path(raw).resolve()
    except OSError:
        return Path(raw)


def _recent_via_shgetfolderpath() -> Path | None:
    try:
        shell32 = ctypes.windll.shell32  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        return None

    buf = ctypes.create_unicode_buffer(_MAX_PATH)
    hr = shell32.SHGetFolderPathW(None, CSIDL_RECENT, None, 0, buf)
    if hr != 0 or not buf.value:
        return None
    try:
        return Path(buf.value).resolve()
    except OSError:
        return Path(buf.value)


def get_shell_recent_folder() -> Path | None:
    """
    Return absolute resolved Recent directory.

    Resolution order: SHGetKnownFolderPath (Known Folder), SHGetFolderPathW (CSIDL_RECENT),
    then `%APPDATA%\\Microsoft\\Windows\\Recent`.
    """
    for getter in (_recent_via_shgetknownfolderpath, _recent_via_shgetfolderpath):
        candidate = getter()
        if candidate is not None:
            return candidate

    fallback = _fallback_recent_dir()
    try:
        return fallback.resolve()
    except OSError:
        return fallback


def normalize_folder_path_str(path: str | Path) -> str:
    """
    Normalize for comparison on Windows: resolved absolute path, stable separators,
    case-insensitive form via os.path.normcase.
    """
    try:
        p = Path(path)
        resolved = p.resolve()
    except OSError:
        resolved = Path(path)
    s = os.path.normpath(str(resolved))
    if len(s) > 3 and s.endswith(("/", "\\")):
        s = s.rstrip("/\\")
    return os.path.normcase(s)


def paths_refer_to_same_folder(a: str | Path, b: str | Path) -> bool:
    return normalize_folder_path_str(a) == normalize_folder_path_str(b)
