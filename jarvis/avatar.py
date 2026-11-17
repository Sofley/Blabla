"""Окно Джарвиса: голографический силуэт, который «говорит», когда Джарвис отвечает.

Свою иллюстрацию можно положить рядом с этим файлом:
  avatar.png       — обычное состояние (рот закрыт), около 300 пикселей в высоту;
  avatar_talk.png  — рот открыт (по желанию; кадры будут чередоваться в такт речи).
"""
import math
import os
import random
import time
import tkinter as tk

HERE = os.path.dirname(os.path.abspath(__file__))

W, H = 380, 560
CX, CY = W // 2, 200          # центр головы
BG = "#04070d"
VOWELS = set("аеёиоуыэюяaeiouy")

MODE_TEXT = {"idle": "В режиме ожидания", "listening": "Слушаю", "thinking": "Думаю…", "speaking": "Говорит"}

THEMES = {
    "голубой": (57, 198, 255),
    "золотой": (255, 196, 70),
    "красный": (255, 80, 70),
    "зеленый": (70, 255, 150),
    "фиолетовый": (180, 110, 255),
}


def _mix(rgb, k):
    k = max(0.0, min(1.0, k))
    bg = (4, 7, 13)
    return "#%02x%02x%02x" % tuple(int(bg[i] + (rgb[i] - bg[i]) * k) for i in range(3))


class AvatarWindow:
    def __init__(self, theme="голубой", on_close=None):
        self.rgb = THEMES.get(theme, THEMES["голубой"])
        self.on_close = on_close
        self.mode = "idle"
        self.text = ""
        self.subtitle = ""
        self.speak_start = 0.0
        self.speak_ms = 0
        self.envelope = []
        self._want_visible = True
        self._visible = True

        self.root = tk.Tk()
        self.root.title("Джарвис")
        self.root.configure(bg=BG)
        self.root.resizable(False, False)
        self.root.attributes("-topmost", True)
        sw, sh = self.root.winfo_screenwidth(), self.root.winfo_screenheight()
        self.root.geometry(f"{W}x{H + 90}+{max(0, sw - W - 30)}+{max(0, sh - H - 170)}")
        self.root.protocol("WM_DELETE_WINDOW", self._close)

        self.canvas = tk.Canvas(self.root, width=W, height=H, bg=BG, highlightthickness=0)
        self.canvas.pack()
        self.status = tk.Label(self.root, text="", fg=_mix(self.rgb, 1), bg=BG, font=("Segoe UI", 12, "bold"))
        self.status.pack()
        self.sub = tk.Label(self.root, text="", fg="#cfe9ff", bg=BG, font=("Segoe UI", 10), wraplength=W - 30,
                            justify="center")
        self.sub.pack(fill="x", padx=10)

        self.img_idle = self._load("avatar.png")
        self.img_talk = self._load("avatar_talk.png")
        self.t0 = time.time()

    # ------------------------------------------------------------ API для Джарвиса (из любого потока)
    def set_mode(self, mode, text=None):
        if self.mode != "speaking" or mode == "speaking":
            self.mode = mode
        if text is not None:
            self.subtitle = text

    def speaking(self, text, duration_ms):
        self.text = text
        self.subtitle = text
        self.speak_ms = max(400, int(duration_ms or len(text) * 70))
        self.envelope = self._make_envelope(text)
        self.speak_start = time.time()
        self.mode = "speaking"

    def idle(self):
        self.mode = "idle"

    def show(self):
        self._want_visible = True

    def hide(self):
        self._want_visible = False

    def set_theme(self, name):
        if name in THEMES:
            self.rgb = THEMES[name]
            return True
        return False

    def run(self):
        self._tick()
        self.root.mainloop()

    # ------------------------------------------------------------ внутреннее
    def _close(self):
        if self.on_close:
            self.on_close()
        self.root.destroy()
        os._exit(0)

    def _load(self, name):
        path = os.path.join(HERE, name)
        if not os.path.exists(path):
            return None
        try:
            img = tk.PhotoImage(file=path)
            k = max(1, math.ceil(max(img.height() / 330, img.width() / 330)))
            return img.subsample(k, k) if k > 1 else img
        except tk.TclError as e:
            print(f"Не удалось загрузить {name}: {e}")
            return None

    @staticmethod
    def _make_envelope(text):
        env = []
        for ch in text.lower():
            if ch in VOWELS:
                env.append(1.0)
            elif ch.isalpha():
                env.append(0.35)
            elif ch in ",.!?;:—-\n":
                env.append(0.0)
                env.append(0.0)
            else:
                env.append(0.1)
        # сглаживание
        sm = []
        for i in range(len(env)):
            win = env[max(0, i - 1): i + 2]
            sm.append(sum(win) / len(win))
        return sm or [0.0]

    def _amp(self, now):
        if self.mode != "speaking":
            return 0.0
        frac = (now - self.speak_start) * 1000 / self.speak_ms
        if frac >= 1.0:
            return 0.0
        idx = int(frac * len(self.envelope))
        a = self.envelope[min(idx, len(self.envelope) - 1)]
        return max(0.0, min(1.0, a * (0.75 + 0.35 * random.random())))

    def _tick(self):
        try:
            self._sync_visibility()
            if self._visible:
                self._draw(time.time())
        except tk.TclError:
            return
        self.root.after(33, self._tick)

    def _sync_visibility(self):
        if self._want_visible != self._visible:
            self._visible = self._want_visible
            if self._visible:
                self.root.deiconify()
                self.root.attributes("-topmost", True)
            else:
                self.root.withdraw()

    def _draw(self, now):
        c = self.canvas
        c.delete("all")
        t = now - self.t0
        amp = self._amp(now)
        self._smooth = getattr(self, "_smooth", 0.0) * 0.55 + amp * 0.45
        a = self._smooth
        mode = self.mode
        rgb = self.rgb

        # --- сетка-фон
        for y in range(0, H, 28):
            c.create_line(0, y, W, y, fill=_mix(rgb, 0.06))
        for x in range(0, W, 28):
            c.create_line(x, 0, x, H, fill=_mix(rgb, 0.06))

        # --- кольца вокруг головы
        speed = {"idle": 12, "listening": 30, "thinking": 140, "speaking": 45}[mode]
        pulse = 0.5 + 0.5 * math.sin(t * (2.2 if mode == "listening" else 1.2))
        for i, (r, ext, dirn) in enumerate([(108, 250, 1), (124, 80, -1), (140, 300, 1), (156, 40, -1)]):
            start = (t * speed * dirn + i * 70) % 360
            bright = 0.25 + 0.25 * pulse + 0.5 * a if mode != "idle" else 0.18 + 0.12 * pulse
            c.create_arc(CX - r, CY - r, CX + r, CY + r, start=start, extent=ext, style="arc",
                         outline=_mix(rgb, bright), width=2 if i % 2 else 3)
        # деления на внешнем кольце
        for k in range(0, 360, 10):
            ang = math.radians(k + t * speed * 0.3)
            r1, r2 = 168, 174 if k % 30 else 180
            c.create_line(CX + r1 * math.cos(ang), CY + r1 * math.sin(ang),
                          CX + r2 * math.cos(ang), CY + r2 * math.sin(ang), fill=_mix(rgb, 0.35))
        if mode == "listening":
            r = 92 + 10 * pulse
            c.create_oval(CX - r, CY - r, CX + r, CY + r, outline=_mix(rgb, 0.5 * (1 - pulse) + 0.2), width=2)

        # --- силуэт или ваша иллюстрация
        if self.img_idle:
            img = self.img_talk if (self.img_talk and a > 0.35) else self.img_idle
            c.create_image(CX, CY + 60, image=img)
        else:
            self._draw_silhouette(c, t, a, mode)

        # --- эквалайзер
        n = 23
        for i in range(n):
            x = 30 + i * (W - 60) / (n - 1)
            centre = 1 - abs(i - n // 2) / (n // 2 + 1)
            if mode == "speaking":
                h = 3 + 34 * a * centre * (0.5 + 0.5 * math.sin(t * 17 + i * 1.7)) ** 2 + 6 * a * random.random()
            elif mode == "thinking":
                h = 3 + 10 * max(0, math.sin(t * 6 - i * 0.6))
            else:
                h = 2 + 3 * (0.5 + 0.5 * math.sin(t * 2 + i * 0.5))
            c.create_line(x, H - 26 - h, x, H - 26 + h, fill=_mix(rgb, 0.5 + 0.5 * centre), width=5,
                          capstyle="round")

        # --- подписи
        self.status.config(text="●  " + MODE_TEXT.get(mode, ""), fg=_mix(rgb, 0.6 + 0.4 * pulse))
        sub = self.subtitle if len(self.subtitle) < 220 else self.subtitle[:217] + "…"
        if self.sub.cget("text") != sub:
            self.sub.config(text=sub)

    # профиль правой половины силуэта: (смещение по y от центра головы, полуширина)
    HEAD = [(-80, 0), (-74, 26), (-58, 46), (-30, 56), (0, 57), (26, 52), (48, 42), (64, 28), (76, 12), (80, 0)]
    BODY = [(58, 23), (106, 27), (122, 62), (136, 110), (152, 148), (175, 168), (215, 176), (300, 180)]

    @staticmethod
    def _interp(profile, dy):
        for (y0, x0), (y1, x1) in zip(profile, profile[1:]):
            if y0 <= dy <= y1:
                return x0 + (x1 - x0) * (dy - y0) / ((y1 - y0) or 1)
        return None

    def _outline(self, profile, breathe):
        right = [(CX + x, CY + y + breathe) for y, x in profile]
        left = [(CX - x, CY + y + breathe) for y, x in reversed(profile)]
        return [v for pt in right + left for v in pt]

    def _draw_silhouette(self, c, t, a, mode):
        rgb = self.rgb
        breathe = math.sin(t * 1.6) * 2.0
        body = self._outline(self.BODY, breathe * 0.5)
        head = self._outline(self.HEAD, breathe)
        glow = 0.35 + 0.65 * a if mode == "speaking" else 0.45
        c.create_polygon(body, smooth=True, fill=_mix(rgb, 0.09), outline="")
        c.create_polygon(head, smooth=True, fill=_mix(rgb, 0.12), outline="")
        # голографические линии поперёк силуэта
        scan = (t * 90) % 380 - 80
        for dy in range(-74, 300, 8):
            half = self._interp(self.HEAD, dy) if dy <= 70 else self._interp(self.BODY, dy)
            if not half or half < 8 or CY + dy > H - 62:
                continue
            k = 0.16 + (0.4 if abs(dy - scan) < 14 else 0)
            y = CY + dy + (breathe if dy <= 70 else breathe * 0.5)
            c.create_line(CX - half + 7, y, CX + half - 7, y, fill=_mix(rgb, k * glow))
        # мягкое свечение контура
        for width, k in ((12, 0.10), (7, 0.2), (4, 0.4), (2, 1.0)):
            col = _mix(rgb, k * glow)
            half_n = len(body) // 2
            c.create_line(body[:half_n], smooth=True, fill=col, width=width)
            c.create_line(body[half_n:], smooth=True, fill=col, width=width)
            c.create_polygon(head, smooth=True, fill="", outline=col, width=width)
        # глаза
        ey = CY - 6 + breathe
        eye = 0.4 + 0.6 * (a if mode == "speaking" else 0.5 + 0.3 * math.sin(t * 3))
        blink = (t % 5.3) < 0.12
        for ex in (CX - 21, CX + 21):
            h = 1 if blink else 3
            c.create_oval(ex - 12, ey - h - 3, ex + 12, ey + h + 3, fill=_mix(rgb, 0.18 * eye), outline="")
            c.create_oval(ex - 8, ey - h, ex + 8, ey + h, fill=_mix(rgb, eye), outline="")
        # рот
        my = CY + 40 + breathe
        open_h = 1 + 11 * a
        c.create_oval(CX - 14 - 3 * a, my - open_h, CX + 14 + 3 * a, my + open_h,
                      fill=_mix(rgb, 0.12 + 0.45 * a), outline=_mix(rgb, 0.45 + 0.55 * a), width=2)
