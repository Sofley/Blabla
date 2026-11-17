"""3D-окно Джарвиса: голова-голограмма в трубе (ui/index.html), открывается в Edge в режиме приложения.

Страница каждые 70 мс спрашивает у Джарвиса /state: что он делает и что говорит.
"""
import ctypes
import json
import os
import shutil
import subprocess
import threading
import time
import webbrowser
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
UI_DIR = os.path.join(HERE, "ui")
THEMES = {"голубой", "золотой", "красный", "зеленый", "фиолетовый"}
SCENES = {"mirror", "tube", "panda"}


def _find_browser():
    pf, pf86 = os.environ.get("ProgramFiles", r"C:\Program Files"), os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")
    local = os.environ.get("LOCALAPPDATA", "")
    for p in (os.path.join(pf86, r"Microsoft\Edge\Application\msedge.exe"),
              os.path.join(pf, r"Microsoft\Edge\Application\msedge.exe"),
              os.path.join(pf, r"Google\Chrome\Application\chrome.exe"),
              os.path.join(pf86, r"Google\Chrome\Application\chrome.exe"),
              os.path.join(local, r"Google\Chrome\Application\chrome.exe"),
              shutil.which("msedge") or "", shutil.which("chrome") or ""):
        if p and os.path.exists(p):
            return p
    return None


class WebAvatar:
    """Тот же набор команд, что у простого окна (avatar.AvatarWindow)."""

    def __init__(self, theme="", port=8765, size=(520, 760), scene="mirror", intro=True):
        theme = (theme or "").replace("ё", "е")
        self.state = {"mode": "idle", "text": "", "speak_id": 0, "speak_ms": 0,
                      "theme": theme if theme in THEMES else "", "visible": True,
                      "scene": scene if scene in SCENES else "mirror",
                      "boot": {"active": intro, "lines": []},
                      "heard": {"text": "", "ok": True, "id": 0}, "ai": False}
        try:
            from natural import HINTS
            self.hints = HINTS
        except Exception:
            self.hints = []
        self.hints_proc = None
        self.intro = intro
        self.lock = threading.Lock()
        self.size = size
        self.proc = None
        self.port = self._start_server(port)

    # ---------------------------------------------------------------- сервер
    def _start_server(self, port):
        avatar = self

        class Handler(SimpleHTTPRequestHandler):
            def do_GET(self):
                if self.path.startswith("/state") or self.path.startswith("/hints.json"):
                    with avatar.lock:
                        data = avatar.state if self.path.startswith("/state") else avatar.hints
                        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json; charset=utf-8")
                    self.send_header("Cache-Control", "no-store")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                    return
                return super().do_GET()

            def log_message(self, *a):
                pass

            def end_headers(self):
                if self.path.endswith((".js", ".glb")):
                    self.send_header("Cache-Control", "no-cache")
                super().end_headers()

        Handler.extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".js": "text/javascript",
                                  ".glb": "model/gltf-binary"}
        for p in range(port, port + 20):
            try:
                self.server = ThreadingHTTPServer(("127.0.0.1", p), partial(Handler, directory=UI_DIR))
                break
            except OSError:
                continue
        else:
            raise RuntimeError("нет свободного порта для окна Джарвиса")
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        return p

    # ---------------------------------------------------------------- окно
    def _open_window(self):
        page = {"mirror": "mirror.html", "panda": "panda.html"}.get(self.state["scene"], "index.html")
        url = f"http://127.0.0.1:{self.port}/{page}"
        browser = _find_browser()
        if not browser:
            webbrowser.open(url)
            return
        w, h, x, y = self._rect(big=self.intro)
        pos = f"{x},{y}"
        profile = os.path.join(HERE, ".window_profile")
        self.proc = subprocess.Popen([browser, f"--app={url}", f"--window-size={w},{h}", f"--window-position={pos}",
                                      f"--user-data-dir={profile}", "--no-first-run", "--disable-features=Translate",
                                      "--ignore-gpu-blocklist"])

    def _rect(self, big=False):
        """Место окна: крупно по центру (заставка) или в правом нижнем углу."""
        try:
            sw = ctypes.windll.user32.GetSystemMetrics(0)
            sh = ctypes.windll.user32.GetSystemMetrics(1)
        except Exception:
            sw, sh = 1600, 900
        if big:
            h = int(sh * .86)
            w = int(h * self.size[0] / self.size[1])
            return w, h, (sw - w) // 2, max(0, (sh - h) // 2 - 20)
        w, h = self.size
        return w, h, max(0, sw - w - 20), max(0, sh - h - 60)

    def _find_hwnd(self):
        try:
            user32 = ctypes.windll.user32
        except Exception:
            return None
        found = []
        proto = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

        def cb(hwnd, _):
            if user32.IsWindowVisible(hwnd):
                buf = ctypes.create_unicode_buffer(256)
                user32.GetWindowTextW(hwnd, buf, 255)
                if buf.value.startswith("Джарвис"):
                    found.append(hwnd)
            return True
        user32.EnumWindows(proto(cb), 0)
        return found[0] if found else None

    def dock(self, seconds=.9):
        """Плавно переносит окно из центра в угол после заставки."""
        if not self.intro:
            return
        self.intro = False
        hwnd = self._find_hwnd()
        if not hwnd:
            return
        user32 = ctypes.windll.user32

        class RECT(ctypes.Structure):
            _fields_ = [("l", ctypes.c_long), ("t", ctypes.c_long), ("r", ctypes.c_long), ("b", ctypes.c_long)]
        r = RECT()
        user32.GetWindowRect(hwnd, ctypes.byref(r))
        a = (r.l, r.t, r.r - r.l, r.b - r.t)
        w, h, x, y = self._rect(big=False)
        b = (x, y, w, h)
        steps = 30
        for i in range(1, steps + 1):
            k = i / steps
            k = 1 - (1 - k) ** 3                      # плавное торможение
            cur = [int(a[j] + (b[j] - a[j]) * k) for j in range(4)]
            user32.MoveWindow(hwnd, cur[0], cur[1], cur[2], cur[3], True)
            time.sleep(seconds / steps)

    # ---------------------------------------------------------------- заставка загрузки
    def boot_step(self, text, status="..."):
        with self.lock:
            lines = [l for l in self.state["boot"]["lines"] if l["text"] != text]
            lines.append({"text": text, "status": status})
            self.state["boot"] = {"active": True, "lines": lines}

    def boot_done(self):
        with self.lock:
            self.state["boot"] = {**self.state["boot"], "active": False}

    # ---------------------------------------------------------------- окно подсказок (слева от Джарвиса)
    def show_hints(self, on=True):
        if not on:
            if self.hints_proc and self.hints_proc.poll() is None:
                self.hints_proc.terminate()
            self.hints_proc = None
            return
        if self.hints_proc and self.hints_proc.poll() is None:
            return
        browser = _find_browser()
        url = f"http://127.0.0.1:{self.port}/hints.html"
        if not browser:
            webbrowser.open(url)
            return
        w, h, x, y = self._rect(big=False)
        hw = 340
        self.hints_proc = subprocess.Popen([browser, f"--app={url}", f"--window-size={hw},{h}",
                                            f"--window-position={max(0, x - hw - 8)},{y}",
                                            f"--user-data-dir={os.path.join(HERE, '.hints_profile')}",
                                            "--no-first-run", "--disable-features=Translate"])

    def set_look(self, x, y):
        """Куда смотреть: курсор относительно центра экрана, от -1 до 1."""
        self.state["look"] = [round(max(-1, min(1, x)), 3), round(max(-1, min(1, y)), 3)]

    def heard(self, text, understood):
        with self.lock:
            self.state["heard"] = {"text": text, "ok": bool(understood), "id": self.state["heard"]["id"] + 1}

    def set_ai(self, ok):
        self._set(ai=bool(ok))

    def _close_window(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
        self.proc = None

    def _set(self, **kw):
        with self.lock:
            self.state.update(kw)

    # ---------------------------------------------------------------- API для Джарвиса
    @property
    def mode(self):
        return self.state["mode"]

    @mode.setter
    def mode(self, value):
        self._set(mode=value)

    def set_mode(self, mode, text=None):
        if self.state["mode"] != "speaking" or mode == "speaking":
            self._set(mode=mode)
        if text is not None:
            self._set(text=text)

    def speaking(self, text, duration_ms):
        self._set(mode="speaking", text=text, speak_ms=max(400, int(duration_ms or len(text) * 70)),
                  speak_id=self.state["speak_id"] + 1)

    def idle(self):
        self._set(mode="idle")

    def show(self):
        self._set(visible=True)
        if not self.proc or self.proc.poll() is not None:
            self._open_window()

    def hide(self):
        self._set(visible=False)
        self._close_window()

    def set_theme(self, name):
        name = name.replace("ё", "е")
        if name in THEMES:
            self._set(theme=name)
            return True
        return False

    def set_scene(self, name):
        if name in SCENES:
            self._set(scene=name)
            return True
        return False

    def run(self):
        self._open_window()
        while True:
            time.sleep(3600)
