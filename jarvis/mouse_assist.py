"""Джарвис следит за мышкой: взгляд за курсором, а по щелчку подсказывает, что можно сделать с объектом.

Слежение взглядом работает всегда (если есть окно Джарвиса). Подсказки по щелчку включаются голосом:
«следи за мышкой» / «помогай с мышкой», выключаются: «не следи за мышкой».
"""
import ctypes
import ctypes.wintypes as W
import os
import threading
import time

try:
    user32 = ctypes.windll.user32
except AttributeError:          # не Windows — модуль ничего не делает
    user32 = None

GA_ROOT = 2
SW_MINIMIZE, SW_MAXIMIZE, SW_RESTORE = 6, 3, 9
WM_CLOSE = 0x0010
VK_LBUTTON = 0x01
JARVIS_TITLES = ("Джарвис", "Подсказки")


def cursor_pos():
    pt = W.POINT()
    user32.GetCursorPos(ctypes.byref(pt))
    return pt.x, pt.y


def screen_size():
    return user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)


def window_title(hwnd):
    buf = ctypes.create_unicode_buffer(512)
    user32.GetWindowTextW(hwnd, buf, 511)
    return buf.value


def window_class(hwnd):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(hwnd, buf, 255)
    return buf.value


def window_process(hwnd):
    pid = W.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    try:
        import psutil
        return os.path.splitext(psutil.Process(pid.value).name())[0]
    except Exception:
        return ""


def root_window_at(x, y):
    hwnd = user32.WindowFromPoint(W.POINT(x, y))
    return user32.GetAncestor(hwnd, GA_ROOT) if hwnd else None


_uia = None


def element_at(x, y):
    """Имя и тип элемента под курсором (ярлык, кнопка, пункт меню) через UI Automation."""
    global _uia
    try:
        import comtypes.client
        if _uia is None:
            comtypes.client.GetModule("UIAutomationCore.dll")
            from comtypes.gen.UIAutomationClient import CUIAutomation, IUIAutomation
            _uia = comtypes.client.CreateObject(CUIAutomation, interface=IUIAutomation)
        from comtypes.gen.UIAutomationClient import tagPOINT
        el = _uia.ElementFromPoint(tagPOINT(x, y))
        return (el.CurrentName or "").strip(), el.CurrentLocalizedControlType or ""
    except Exception:
        return "", ""


def minimize(hwnd):
    user32.ShowWindow(hwnd, SW_MINIMIZE)


def maximize(hwnd):
    user32.ShowWindow(hwnd, SW_MAXIMIZE)


def restore(hwnd):
    user32.ShowWindow(hwnd, SW_RESTORE)
    user32.SetForegroundWindow(hwnd)


def close(hwnd):
    user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)


def double_click_at(x, y):
    import pyautogui
    pyautogui.doubleClick(x, y)


def foreground():
    return user32.GetForegroundWindow()


class MouseAssist:
    """Фоновый поток: взгляд Джарвиса за курсором и события щелчков."""

    def __init__(self, ui, on_click):
        self.ui = ui
        self.on_click = on_click
        self.helping = False         # подсказки по щелчку
        self.last = None             # последний объект: dict(hwnd, title, app, name, kind, x, y)
        self._last_click_t = 0
        if user32:
            threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        was_down = False
        sw, sh = screen_size()
        while True:
            try:
                x, y = cursor_pos()
                if self.ui and hasattr(self.ui, "set_look"):
                    self.ui.set_look((x - sw / 2) / (sw / 2), (y - sh / 2) / (sh / 2))
                down = bool(user32.GetAsyncKeyState(VK_LBUTTON) & 0x8000)
                if was_down and not down and self.helping:
                    self._clicked(x, y)
                was_down = down
            except Exception:
                pass
            time.sleep(.08)

    def _clicked(self, x, y):
        hwnd = root_window_at(x, y)
        if not hwnd:
            return
        title = window_title(hwnd)
        if title.startswith(JARVIS_TITLES):
            return
        name, kind = element_at(x, y)
        cls = window_class(hwnd)
        target = {"hwnd": hwnd, "title": title, "app": window_process(hwnd), "name": name, "kind": kind,
                  "x": x, "y": y, "desktop": cls in ("Progman", "WorkerW"), "taskbar": cls == "Shell_TrayWnd"}
        same = self.last and self.last.get("hwnd") == hwnd and self.last.get("name") == name
        self.last = target
        now = time.time()
        if same and now - self._last_click_t < 6:
            return                    # тот же объект — не повторяемся
        self._last_click_t = now
        self.on_click(target)


def describe(target):
    """Как назвать объект вслух и что предложить."""
    if target.get("desktop") and target.get("name"):
        return f"Ярлык «{target['name']}». Открыть?", "desktop_item"
    if target.get("taskbar") and target.get("name"):
        return f"«{target['name']}» на панели задач. Открыть или закрыть?", "taskbar_item"
    who = target.get("title") or target.get("app") or "Окно"
    who = who if len(who) <= 60 else who[:57] + "…"
    return f"{who}. Свернуть, развернуть или закрыть?", "window"
