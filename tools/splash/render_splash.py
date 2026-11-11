#!/usr/bin/env python3
"""Render the NexusTrade animated splash (frames -> GIF / MP4 / PNG).

Uses the layered logo in assets/splash (emblem, wordmark, underline cut from
the original logo with a luminance key) plus procedural layers: a digital
world map, trade routes, a light burst, a slowly rotating dot globe, orbits
with travelling particles, a metallic shine and the wordmark reveal.
The same timeline is implemented in lib/ui/splash/animated_logo.dart.

Usage:  python3 tools/splash/render_splash.py OUT_DIR
Needs:  numpy, Pillow, ffmpeg in PATH.
"""

import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, 'assets', 'splash')
W, H = 1080, 1920
INTRO = 4.6          # seconds
LOOP = 2.0           # seconds, seamless
FPS_GIF, FPS_MP4 = 24, 30

# ---------------------------------------------------------------- layout
EMB = Image.open(os.path.join(ASSETS, 'emblem.png')).convert('RGBA')
WORD = Image.open(os.path.join(ASSETS, 'wordmark.png')).convert('RGBA')
LINE = Image.open(os.path.join(ASSETS, 'underline.png')).convert('RGBA')
EW = 900
ES = EW / EMB.width
EMB_S = EMB.resize((EW, round(EMB.height * ES)), Image.LANCZOS)
EX, EY = (W - EW) // 2, round(820 - EMB_S.height / 2)
GX, GY, GR = EX + 453 * ES, EY + 344 * ES, 300 * ES       # globe circle
WW = 860
WORD_S = WORD.resize((WW, round(WORD.height * WW / WORD.width)), Image.LANCZOS)
WX, WY = (W - WW) // 2, 1300 - WORD_S.height // 2
LW = 760
LINE_S = LINE.resize((LW, round(LINE.height * LW / LINE.width)), Image.LANCZOS)
LX, LY = (W - LW) // 2, WY + WORD_S.height + 22

MASK = Image.open(os.path.join(ASSETS, 'globe_mask.png')).convert('L').resize(EMB_S.size, Image.LANCZOS)
DOTS = json.load(open(os.path.join(os.path.dirname(__file__), 'world_dots.json')))
HUBS = {
    'Shanghai': (31.2, 121.5), 'Qingdao': (36.1, 120.4), 'Ningbo': (29.9, 121.6),
    "Xi'an": (34.3, 108.9), 'Tashkent': (41.3, 69.2), 'Almaty': (43.2, 76.9),
    'Dubai': (25.2, 55.3), 'Istanbul': (41.0, 29.0), 'Moscow': (55.8, 37.6),
    'Rotterdam': (51.9, 4.5), 'Hamburg': (53.6, 10.0), 'Poti': (42.1, 41.7),
    'Mumbai': (19.1, 72.9), 'Singapore': (1.3, 103.8),
}
ROUTES = [('Shanghai', 'Tashkent'), ('Qingdao', 'Poti'), ("Xi'an", 'Tashkent'),
          ('Ningbo', 'Dubai'), ('Shanghai', 'Rotterdam'), ('Tashkent', 'Moscow'),
          ('Dubai', 'Istanbul'), ('Istanbul', 'Hamburg'), ('Singapore', 'Mumbai'),
          ('Mumbai', 'Dubai'), ('Almaty', 'Moscow'), ('Shanghai', 'Singapore')]

GOLD = np.array([232, 188, 92], np.float32)
CYAN = np.array([80, 200, 255], np.float32)
BLUE = np.array([30, 120, 255], np.float32)


def clamp01(v):
    return max(0.0, min(1.0, v))


def phase(t, a, b):
    """0..1 progress of t inside [a, b], eased."""
    p = clamp01((t - a) / (b - a))
    return p * p * (3 - 2 * p)


def map_xy(lat, lon):
    k = 5.4
    return 540 + (lon - 60) * k, 820 - (lat - 25) * k


def globe_xyz(lat, lon, lon0, tilt=math.radians(18)):
    phi, lam = math.radians(lat), math.radians(lon - lon0)
    x = math.cos(phi) * math.sin(lam)
    y = math.cos(tilt) * math.sin(phi) - math.sin(tilt) * math.cos(phi) * math.cos(lam)
    z = math.sin(tilt) * math.sin(phi) + math.cos(tilt) * math.cos(phi) * math.cos(lam)
    return GX + GR * .96 * x, GY - GR * .96 * y, z


def bezier(p0, p1, p2, s):
    return ((1 - s) ** 2 * p0[0] + 2 * (1 - s) * s * p1[0] + s * s * p2[0],
            (1 - s) ** 2 * p0[1] + 2 * (1 - s) * s * p1[1] + s * s * p2[1])


def route_points(a, b):
    p0, p2 = map_xy(*HUBS[a]), map_xy(*HUBS[b])
    mx, my = (p0[0] + p2[0]) / 2, (p0[1] + p2[1]) / 2
    dx, dy = p2[0] - p0[0], p2[1] - p0[1]
    ln = math.hypot(dx, dy) or 1
    p1 = (mx + dy / ln * ln * .18, my - abs(dx) / ln * ln * .18)
    return p0, p1, p2


def orbit_point(i, theta):
    rx, ry, rot = [(1.34, .34, -14), (1.22, .50, 22)][i]
    rot = math.radians(rot)
    x, y = GR * rx * math.cos(theta), GR * ry * math.sin(theta)
    return (GX + x * math.cos(rot) - y * math.sin(rot),
            GY + x * math.sin(rot) + y * math.cos(rot), math.sin(theta))


def add(canvas, layer, color, gain=1.0, blur=0):
    """Additive glow: layer is an L image (0..255)."""
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(layer, np.float32)[..., None] / 255.0
    canvas += a * color * gain


def over(canvas, rgba, x, y, opacity=1.0):
    a = np.asarray(rgba, np.float32)
    h, w = a.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    sub = a[y0 - y:y1 - y, x0 - x:x1 - x]
    al = sub[..., 3:4] / 255.0 * opacity
    region = canvas[y0:y1, x0:x1]
    canvas[y0:y1, x0:x1] = region * (1 - al) + sub[..., :3] * al


def render(t, loop_mode=False):
    c = np.zeros((H, W, 3), np.float32)

    # Scene 1 — digital world map + network
    map_a = .30 * phase(t, 0.0, 1.0) - .18 * phase(t, 1.4, 2.4)
    lay = Image.new('L', (W, H))
    d = ImageDraw.Draw(lay)
    for lat, lon in DOTS['map']:
        x, y = map_xy(lat, lon)
        if -10 < x < W + 10 and -10 < y < H + 10:
            d.ellipse((x - 2.2, y - 2.2, x + 2.2, y + 2.2), fill=255)
    add(c, lay, CYAN, map_a)

    net = phase(t, .4, 1.6)
    net_a = 1.0 - .8 * phase(t, 1.6, 2.6)
    lay = Image.new('L', (W, H))
    d = ImageDraw.Draw(lay)
    pulses = Image.new('L', (W, H))
    dp = ImageDraw.Draw(pulses)
    for k, (a, b) in enumerate(ROUTES):
        p0, p1, p2 = route_points(a, b)
        local = clamp01(net * 1.6 - k * .05)
        if local <= 0:
            continue
        pts = [bezier(p0, p1, p2, s / 40 * local) for s in range(41)]
        d.line(pts, fill=200, width=2)
        s = ((t / LOOP) + k * .37) % 1.0
        if local >= 1:
            x, y = bezier(p0, p1, p2, s)
            dp.ellipse((x - 5, y - 5, x + 5, y + 5), fill=255)
    for name, (lat, lon) in HUBS.items():
        x, y = map_xy(lat, lon)
        d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=255 if net > .2 else 0)
    add(c, lay, CYAN, .55 * net_a)
    add(c, lay, BLUE, .9 * net_a, blur=6)
    add(c, pulses, np.array([255, 240, 200], np.float32), .9 * net_a, blur=2)

    # Light burst in the centre
    burst = phase(t, .6, 1.25) * (1 - .85 * phase(t, 1.25, 2.2))
    if burst > 0:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.hypot(xx - GX, yy - GY)
        rad = 120 + 380 * phase(t, .6, 1.4) - 120 * phase(t, 1.4, 2.2)
        g = np.exp(-(r / rad) ** 2)[..., None]
        c += g * BLUE * burst * .9

    # Orbits behind the globe
    orb_draw = phase(t, 1.4, 2.4)
    _orbits(c, t, orb_draw, front=False)

    # Scene 2/3 — emblem materialises
    em_p = phase(t, 1.2, 2.2)
    if em_p > 0:
        sc = .88 + .12 * em_p
        img = EMB_S.resize((round(EW * sc), round(EMB_S.height * sc)), Image.LANCZOS)
        blur = 12 * (1 - em_p)
        if blur > .3:
            img = img.filter(ImageFilter.GaussianBlur(blur))
        x = round(GX - (GX - EX) * sc)
        y = round(GY - (GY - EY) * sc)
        over(c, img, x, y, em_p)

    # Rotating dot globe (subtle) + twinkling hubs
    gl = .26 * phase(t, 1.6, 2.6)
    if gl > 0:
        lon0 = 62 - 1.5 * t          # 3° (one grid step) every LOOP seconds
        lay = Image.new('L', (W, H))
        d = ImageDraw.Draw(lay)
        for lat, lon in DOTS['globe']:
            x, y, z = globe_xyz(lat, lon, lon0)
            if z > 0:
                rr = .8 + 2.0 * z
                d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=int(255 * z ** 1.2))
        full = Image.new('L', (W, H))
        full.paste(MASK, (EX, EY))
        lay = Image.fromarray((np.asarray(lay, np.float32) * np.asarray(full, np.float32) / 255).astype(np.uint8))
        add(c, lay, CYAN, gl)
        tw = Image.new('L', (W, H))
        d = ImageDraw.Draw(tw)
        for k, (lat, lon) in enumerate(HUBS.values()):
            x, y, z = globe_xyz(lat, lon, lon0)
            if z > .15:
                pulse = .5 + .5 * math.sin(2 * math.pi * (t / LOOP + k * .23))
                rr = 3 + 3 * pulse
                d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=int(255 * z * pulse))
        add(c, tw, np.array([200, 240, 255], np.float32), gl * 2.2, blur=3)

    # Orbits in front of the globe
    _orbits(c, t, orb_draw, front=True)

    # Metallic shine across the emblem
    sh = (t - 2.3) / .8
    if 0 <= sh <= 1 and not loop_mode:
        a = np.asarray(EMB_S, np.float32)
        h, w = a.shape[:2]
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        pos = -300 + (w + h + 300) * sh
        band = np.exp(-(((xx + yy * .6) - pos) / 70) ** 2)
        al = (a[..., 3] / 255.0) ** 1.4
        c[EY:EY + h, EX:EX + w] += (band * al)[..., None] * np.array([255, 245, 220]) * .55

    # Scene 4 — wordmark, underline and glow
    wp = phase(t, 2.9, 3.6)
    if wp > 0:
        glow = Image.new('L', (W, H))
        d = ImageDraw.Draw(glow)
        cy = WY + WORD_S.height + 8
        d.ellipse((W / 2 - 360, cy - 24, W / 2 + 360, cy + 24), fill=255)
        add(c, glow, BLUE, .55 * phase(t, 3.0, 3.8), blur=40)
        over(c, WORD_S, WX, WY + round(30 * (1 - wp)), wp)
    lp = phase(t, 3.2, 3.9)
    if lp > 0:
        cw = max(2, round(LW * lp))
        crop = LINE_S.crop(((LW - cw) // 2, 0, (LW + cw) // 2, LINE_S.height))
        over(c, crop, (W - cw) // 2, LY, min(1.0, lp * 1.4))

    return Image.fromarray(np.clip(c, 0, 255).astype(np.uint8), 'RGB')


def _orbits(c, t, draw_p, front):
    if draw_p <= 0:
        return
    lay = Image.new('L', (W, H))
    d = ImageDraw.Draw(lay)
    parts = Image.new('L', (W, H))
    dp = ImageDraw.Draw(parts)
    for i in range(2):
        n = 160
        pts = []
        for s in range(n + 1):
            th = 2 * math.pi * s / n * draw_p - math.pi / 2
            x, y, z = orbit_point(i, th)
            if (z > 0) == front:
                pts.append((x, y))
            elif pts:
                d.line(pts, fill=120 if front else 60, width=2)
                pts = []
        if len(pts) > 1:
            d.line(pts, fill=120 if front else 60, width=2)
        if draw_p >= 1:
            for k in range(3):
                th = 2 * math.pi * (k / 3 + t / (3 * LOOP))
                x, y, z = orbit_point(i, th)
                if (z > 0) == front:
                    rr = 6 if front else 4
                    dp.ellipse((x - rr, y - rr, x + rr, y + rr), fill=255)
        color = GOLD if i == 0 else CYAN
        add(c, lay, color, .5)
        add(c, lay, color, .35, blur=6)
        add(c, parts, np.array([255, 250, 230], np.float32), 1.0, blur=2)
        add(c, parts, color, 1.2, blur=10)
        lay = Image.new('L', (W, H))
        d = ImageDraw.Draw(lay)
        parts = Image.new('L', (W, H))
        dp = ImageDraw.Draw(parts)


def main(out):
    os.makedirs(os.path.join(out, 'frames'), exist_ok=True)
    os.makedirs(os.path.join(out, 'loop'), exist_ok=True)
    n = round(INTRO * FPS_MP4)
    for i in range(n):
        render(i / FPS_MP4).save(os.path.join(out, 'frames', f'{i:04d}.png'))
        print(f'intro {i + 1}/{n}', end='\r', flush=True)
    m = round(LOOP * FPS_GIF)
    for i in range(m):
        render(INTRO + i / FPS_GIF, loop_mode=True).save(os.path.join(out, 'loop', f'{i:04d}.png'))
    render(INTRO).save(os.path.join(out, 'NexusTrade_splash_final.png'))
    ff = 'ffmpeg -y -loglevel error'
    sh = lambda cmd: subprocess.run(cmd, shell=True, check=True)
    # MP4: H.264, yuv420p, fast start — plays on every Android device.
    sh(f"{ff} -framerate {FPS_MP4} -i {out}/frames/%04d.png -c:v libx264 -preset slow "
       f"-crf 20 -pix_fmt yuv420p -movflags +faststart {out}/NexusTrade_splash.mp4")
    # GIF intro (plays once) and seamless loop, palette-optimised.
    for name, src, fps, loop in [('NexusTrade_splash', 'frames/%04d.png', FPS_MP4, -1),
                                 ('NexusTrade_splash_loop', 'loop/%04d.png', FPS_GIF, 0)]:
        rate = f'-framerate {fps}'
        vf = f'fps={FPS_GIF},scale=1080:-1:flags=lanczos'
        sh(f"{ff} {rate} -i {out}/{src} -vf \"{vf},palettegen=max_colors=192:stats_mode=diff\" {out}/pal.png")
        sh(f"{ff} {rate} -i {out}/{src} -i {out}/pal.png -lavfi \"{vf}[x];[x][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle\" "
           f"-loop {loop} {out}/{name}.gif")
    print('\ndone')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'splash_out')
