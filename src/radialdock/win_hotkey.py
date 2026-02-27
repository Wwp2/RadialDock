from __future__ import annotations

import ctypes
from ctypes import wintypes
from typing import Callable

from PySide6.QtCore import QAbstractNativeEventFilter, QObject, Signal

WM_HOTKEY = 0x0312

MOD_ALT = 0x0001
MOD_CONTROL = 0x0002
MOD_SHIFT = 0x0004
MOD_WIN = 0x0008

VK_SPACE = 0x20
VK_F1 = 0x70
VK_F24 = 0x87

_MODIFIERS = {
    "ALT": MOD_ALT,
    "CTRL": MOD_CONTROL,
    "CONTROL": MOD_CONTROL,
    "SHIFT": MOD_SHIFT,
    "WIN": MOD_WIN,
    "WINDOWS": MOD_WIN,
}

_SPECIAL_KEYS = {
    "SPACE": VK_SPACE,
}


class MSG(ctypes.Structure):
    _fields_ = [
        ("hwnd", wintypes.HWND),
        ("message", wintypes.UINT),
        ("wParam", wintypes.WPARAM),
        ("lParam", wintypes.LPARAM),
        ("time", wintypes.DWORD),
        ("pt", wintypes.POINT),
        ("lPrivate", wintypes.DWORD),
    ]


user32 = ctypes.windll.user32
user32.RegisterHotKey.argtypes = [wintypes.HWND, ctypes.c_int, wintypes.UINT, wintypes.UINT]
user32.RegisterHotKey.restype = wintypes.BOOL
user32.UnregisterHotKey.argtypes = [wintypes.HWND, ctypes.c_int]
user32.UnregisterHotKey.restype = wintypes.BOOL


class _HotkeyFilter(QAbstractNativeEventFilter):
    def __init__(self, hotkey_id: int, callback: Callable[[], None]) -> None:
        super().__init__()
        self._hotkey_id = hotkey_id
        self._callback = callback

    def nativeEventFilter(self, event_type: bytes, message: int) -> tuple[bool, int]:
        if event_type not in (b"windows_generic_MSG", b"windows_dispatcher_MSG"):
            return False, 0
        msg = MSG.from_address(int(message))
        if msg.message == WM_HOTKEY and int(msg.wParam) == self._hotkey_id:
            self._callback()
            return True, 0
        return False, 0


class GlobalHotkeyManager(QObject):
    activated = Signal()

    def __init__(self, parent: QObject | None = None, hotkey_id: int = 1) -> None:
        super().__init__(parent)
        self._hotkey_id = hotkey_id
        self._registered = False
        self._app = parent
        if self._app is None:
            raise ValueError("GlobalHotkeyManager requires a QGuiApplication parent.")
        self._filter = _HotkeyFilter(self._hotkey_id, self._emit_activated)
        self._app.installNativeEventFilter(self._filter)

    def _emit_activated(self) -> None:
        self.activated.emit()

    def register(self, modifiers: int, virtual_key: int) -> bool:
        if self._registered:
            self.unregister()
        ok = bool(user32.RegisterHotKey(None, self._hotkey_id, modifiers, virtual_key))
        self._registered = ok
        return ok

    def register_from_string(self, hotkey: str) -> bool:
        modifiers, vk = parse_hotkey(hotkey)
        return self.register(modifiers=modifiers, virtual_key=vk)

    def unregister(self) -> None:
        if self._registered:
            user32.UnregisterHotKey(None, self._hotkey_id)
            self._registered = False


def parse_hotkey(hotkey: str) -> tuple[int, int]:
    tokens = [part.strip().upper() for part in hotkey.split("+") if part.strip()]
    if len(tokens) < 2:
        raise ValueError("Hotkey must include at least one modifier and one key.")

    modifiers = 0
    for token in tokens[:-1]:
        if token not in _MODIFIERS:
            raise ValueError(f"Unsupported modifier: {token}")
        modifiers |= _MODIFIERS[token]

    key = tokens[-1]
    virtual_key = _key_to_vk(key)
    if modifiers == 0:
        raise ValueError("At least one modifier is required.")
    return modifiers, virtual_key


def _key_to_vk(token: str) -> int:
    if token in _SPECIAL_KEYS:
        return _SPECIAL_KEYS[token]
    if len(token) == 1 and "A" <= token <= "Z":
        return ord(token)
    if len(token) == 1 and token.isdigit():
        return ord(token)
    if token.startswith("F") and token[1:].isdigit():
        candidate = int(token[1:])
        if 1 <= candidate <= 24:
            return VK_F1 + (candidate - 1)
    raise ValueError(f"Unsupported key: {token}")
