from __future__ import annotations

import ctypes
from ctypes import wintypes
from dataclasses import dataclass
from typing import Callable

from PySide6.QtCore import QAbstractNativeEventFilter, QObject, Signal

WM_LBUTTONDOWN = 0x0201
WM_RBUTTONDOWN = 0x0204
WM_MBUTTONDOWN = 0x0207
WM_XBUTTONDOWN = 0x020B
WM_HOTKEY = 0x0312
WH_MOUSE_LL = 14

MOD_ALT = 0x0001
MOD_CONTROL = 0x0002
MOD_SHIFT = 0x0004
MOD_WIN = 0x0008

VK_SPACE = 0x20
VK_TAB = 0x09
VK_RETURN = 0x0D
VK_ESCAPE = 0x1B
VK_BACK = 0x08
VK_INSERT = 0x2D
VK_DELETE = 0x2E
VK_HOME = 0x24
VK_END = 0x23
VK_PRIOR = 0x21
VK_NEXT = 0x22
VK_LEFT = 0x25
VK_UP = 0x26
VK_RIGHT = 0x27
VK_DOWN = 0x28
VK_F1 = 0x70
VK_F24 = 0x87
XBUTTON1 = 0x0001
XBUTTON2 = 0x0002

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
    "TAB": VK_TAB,
    "ENTER": VK_RETURN,
    "RETURN": VK_RETURN,
    "ESC": VK_ESCAPE,
    "ESCAPE": VK_ESCAPE,
    "BACKSPACE": VK_BACK,
    "INSERT": VK_INSERT,
    "DELETE": VK_DELETE,
    "HOME": VK_HOME,
    "END": VK_END,
    "PGUP": VK_PRIOR,
    "PAGEUP": VK_PRIOR,
    "PGDN": VK_NEXT,
    "PAGEDOWN": VK_NEXT,
    "LEFT": VK_LEFT,
    "UP": VK_UP,
    "RIGHT": VK_RIGHT,
    "DOWN": VK_DOWN,
}

_MOUSE_BUTTON_ALIASES = {
    "MOUSELEFT": "MouseLeft",
    "LEFTMOUSE": "MouseLeft",
    "LEFTCLICK": "MouseLeft",
    "LMB": "MouseLeft",
    "MOUSELEFTBUTTON": "MouseLeft",
    "MOUSERIGHT": "MouseRight",
    "RIGHTMOUSE": "MouseRight",
    "RIGHTCLICK": "MouseRight",
    "RMB": "MouseRight",
    "MOUSERIGHTBUTTON": "MouseRight",
    "MOUSEMIDDLE": "MouseMiddle",
    "MIDDLEMOUSE": "MouseMiddle",
    "MIDDLECLICK": "MouseMiddle",
    "MMB": "MouseMiddle",
    "MOUSEX1": "MouseX1",
    "MOUSE4": "MouseX1",
    "XBUTTON1": "MouseX1",
    "XBUTTON4": "MouseX1",
    "MOUSEX2": "MouseX2",
    "MOUSE5": "MouseX2",
    "XBUTTON2": "MouseX2",
    "XBUTTON5": "MouseX2",
}

_MOUSE_MESSAGE_MATCH = {
    "MouseLeft": (WM_LBUTTONDOWN, None),
    "MouseRight": (WM_RBUTTONDOWN, None),
    "MouseMiddle": (WM_MBUTTONDOWN, None),
    "MouseX1": (WM_XBUTTONDOWN, XBUTTON1),
    "MouseX2": (WM_XBUTTONDOWN, XBUTTON2),
}


@dataclass(frozen=True)
class HotkeySpec:
    kind: str
    display: str
    modifiers: int = 0
    virtual_key: int = 0
    mouse_button: str = ""


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


class MSLLHOOKSTRUCT(ctypes.Structure):
    _fields_ = [
        ("pt", wintypes.POINT),
        ("mouseData", wintypes.DWORD),
        ("flags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.c_void_p),
    ]


user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32
user32.RegisterHotKey.argtypes = [wintypes.HWND, ctypes.c_int, wintypes.UINT, wintypes.UINT]
user32.RegisterHotKey.restype = wintypes.BOOL
user32.UnregisterHotKey.argtypes = [wintypes.HWND, ctypes.c_int]
user32.UnregisterHotKey.restype = wintypes.BOOL
LowLevelMouseProc = ctypes.WINFUNCTYPE(wintypes.LPARAM, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM)
user32.SetWindowsHookExW.argtypes = [ctypes.c_int, LowLevelMouseProc, wintypes.HINSTANCE, wintypes.DWORD]
user32.SetWindowsHookExW.restype = wintypes.HHOOK
user32.CallNextHookEx.argtypes = [wintypes.HHOOK, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM]
user32.CallNextHookEx.restype = wintypes.LPARAM
user32.UnhookWindowsHookEx.argtypes = [wintypes.HHOOK]
user32.UnhookWindowsHookEx.restype = wintypes.BOOL
kernel32.GetModuleHandleW.argtypes = [wintypes.LPCWSTR]
kernel32.GetModuleHandleW.restype = wintypes.HMODULE


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
        self._mouse_hook: wintypes.HHOOK | None = None
        self._mouse_callback: LowLevelMouseProc | None = None
        self._mouse_button: str | None = None
        self._app = parent
        if self._app is None:
            raise ValueError("GlobalHotkeyManager requires a QGuiApplication parent.")
        self._filter = _HotkeyFilter(self._hotkey_id, self._emit_activated)
        self._app.installNativeEventFilter(self._filter)

    def _emit_activated(self) -> None:
        self.activated.emit()

    def register(self, modifiers: int, virtual_key: int) -> bool:
        self.unregister()
        ok = bool(user32.RegisterHotKey(None, self._hotkey_id, modifiers, virtual_key))
        self._registered = ok
        return ok

    def register_from_string(self, hotkey: str) -> bool:
        spec = parse_hotkey(hotkey)
        return self.register_spec(spec)

    def register_spec(self, spec: HotkeySpec) -> bool:
        if spec.kind == "mouse":
            return self._register_mouse(spec.mouse_button)
        return self.register(modifiers=spec.modifiers, virtual_key=spec.virtual_key)

    def _register_mouse(self, mouse_button: str) -> bool:
        self.unregister()
        if mouse_button not in _MOUSE_MESSAGE_MATCH:
            return False

        expected_message, expected_xbutton = _MOUSE_MESSAGE_MATCH[mouse_button]

        def callback(n_code: int, w_param: int, l_param: int) -> int:
            if n_code >= 0:
                if int(w_param) == expected_message:
                    if expected_message == WM_XBUTTONDOWN:
                        info = MSLLHOOKSTRUCT.from_address(int(l_param))
                        button_data = (int(info.mouseData) >> 16) & 0xFFFF
                        if button_data == expected_xbutton:
                            self._emit_activated()
                    else:
                        self._emit_activated()
            return int(user32.CallNextHookEx(self._mouse_hook, n_code, w_param, l_param))

        self._mouse_callback = LowLevelMouseProc(callback)
        module_handle = kernel32.GetModuleHandleW(None)
        hook = user32.SetWindowsHookExW(WH_MOUSE_LL, self._mouse_callback, module_handle, 0)
        if not hook:
            self._mouse_callback = None
            self._mouse_button = None
            return False

        self._mouse_hook = hook
        self._mouse_button = mouse_button
        return True

    def unregister(self) -> None:
        if self._registered:
            user32.UnregisterHotKey(None, self._hotkey_id)
            self._registered = False
        if self._mouse_hook:
            user32.UnhookWindowsHookEx(self._mouse_hook)
            self._mouse_hook = None
            self._mouse_callback = None
            self._mouse_button = None


def parse_hotkey(hotkey: str) -> HotkeySpec:
    tokens = [part.strip().upper() for part in hotkey.split("+") if part.strip()]
    if not tokens:
        raise ValueError("Shortcut cannot be empty.")

    if len(tokens) == 1 and tokens[0] in _MOUSE_BUTTON_ALIASES:
        canonical = _MOUSE_BUTTON_ALIASES[tokens[0]]
        return HotkeySpec(kind="mouse", display=canonical, mouse_button=canonical)

    modifiers = 0
    for token in tokens[:-1]:
        if token not in _MODIFIERS:
            raise ValueError(f"Unsupported modifier: {token}")
        modifiers |= _MODIFIERS[token]

    key = tokens[-1]
    virtual_key = _key_to_vk(key)
    return HotkeySpec(
        kind="keyboard",
        display=_format_hotkey_display(tokens, key),
        modifiers=modifiers,
        virtual_key=virtual_key,
    )


def normalize_hotkey(hotkey: str) -> str:
    return parse_hotkey(hotkey).display


def _format_hotkey_display(tokens: list[str], key_token: str) -> str:
    modifier_names: list[str] = []
    for token in tokens[:-1]:
        if token in ("CTRL", "CONTROL"):
            modifier_names.append("Ctrl")
        elif token == "ALT":
            modifier_names.append("Alt")
        elif token == "SHIFT":
            modifier_names.append("Shift")
        elif token in ("WIN", "WINDOWS"):
            modifier_names.append("Win")

    key_display = _display_key(key_token)
    if modifier_names:
        return "+".join([*modifier_names, key_display])
    return key_display


def _display_key(token: str) -> str:
    pretty = {
        "SPACE": "Space",
        "TAB": "Tab",
        "ENTER": "Enter",
        "RETURN": "Enter",
        "ESC": "Esc",
        "ESCAPE": "Esc",
        "BACKSPACE": "Backspace",
        "INSERT": "Insert",
        "DELETE": "Delete",
        "HOME": "Home",
        "END": "End",
        "PGUP": "PgUp",
        "PAGEUP": "PgUp",
        "PGDN": "PgDn",
        "PAGEDOWN": "PgDn",
        "LEFT": "Left",
        "UP": "Up",
        "RIGHT": "Right",
        "DOWN": "Down",
    }
    if token in pretty:
        return pretty[token]
    return token


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
