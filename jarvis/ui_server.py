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
SCENES = {"mirror", "tube"}


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

    def __init__(self, theme="", port=8765, size=(520, 760), scene="mirror"):
        theme = (theme or "").replace("ё", "е")
        self.state = {"mode": "idle", "text": "", "speak_id": 0, "speak_ms": 0,
                      "theme": theme if theme in THEMES else "", "visible": True,
                      "scene": scene if scene in SCENES else "mirror"}
        self.lock = threading.Lock()
        self.size = size
        self.proc = None
        self.port = self._start_server(port)

    # ---------------------------------------------------------------- сервер
    def _start_server(self, port):
        avatar = self

        class Handler(SimpleHTTPRequestHandler):
            def do_GET(self):
                if self.path.startswith("/state"):
                    with avatar.lock:
                        body = json.dumps(avatar.state, ensure_ascii=False).encode("utf-8")
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
        page = "mirror.html" if self.state["scene"] == "mirror" else "index.html"
        url = f"http://127.0.0.1:{self.port}/{page}"
        browser = _find_browser()
        if not browser:
            webbrowser.open(url)
            return
        w, h = self.size
        try:
            sw = ctypes.windll.user32.GetSystemMetrics(0)
            sh = ctypes.windll.user32.GetSystemMetrics(1)
            pos = f"{max(0, sw - w - 20)},{max(0, sh - h - 60)}"
        except Exception:
            pos = "100,100"
        profile = os.path.join(HERE, ".window_profile")
        self.proc = subprocess.Popen([browser, f"--app={url}", f"--window-size={w},{h}", f"--window-position={pos}",
                                      f"--user-data-dir={profile}", "--no-first-run", "--disable-features=Translate",
                                      "--ignore-gpu-blocklist"])

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
