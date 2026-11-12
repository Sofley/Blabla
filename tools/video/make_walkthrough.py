"""4K silent UI walkthrough: real app frames (recorded by
test/tools/walkthrough_tool_test.dart) + animated finger, taps, ripples.
Usage: python3 tools/video/make_walkthrough.py <frames_dir> <out.mp4>"""
import json, math, subprocess, sys
from PIL import Image, ImageDraw, ImageFilter

SRC, OUT = sys.argv[1], sys.argv[2]
W, H, FPS = 3840, 2160, 30
tl = json.load(open(f'{SRC}/timeline.json'))

# ---------- static scene ----------
def background():
    bg = Image.new('RGB', (W, H), (6, 9, 16))
    glow = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(glow)
    for r, a in [(1500, 40), (1100, 60), (750, 80)]:
        d.ellipse([W/2 - r, H/2 - r*0.75, W/2 + r, H/2 + r*0.75], fill=a)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    tint = Image.new('RGB', (W, H), (20, 52, 110))
    bg = Image.composite(tint, bg, glow)
    # faint dot grid
    d = ImageDraw.Draw(bg)
    for x in range(60, W, 120):
        for y in range(60, H, 120):
            d.ellipse([x-2, y-2, x+2, y+2], fill=(22, 30, 46))
    return bg

screen0 = Image.open(f'{SRC}/{tl[0]["img"]}').convert('RGB')
SW, SH = screen0.size          # 864 x 1920
BEZ = 26
PW, PH = SW + BEZ*2, SH + BEZ*2
PX, PY = (W - PW)//2, (H - PH)//2
SX, SY = PX + BEZ, PY + BEZ

bg = background()
# shadow + phone body
sh = Image.new('L', (W, H), 0)
ImageDraw.Draw(sh).rounded_rectangle([PX+40, PY+70, PX+PW+40, PY+PH+70], 110, fill=170)
sh = sh.filter(ImageFilter.GaussianBlur(70))
bg = Image.composite(Image.new('RGB', (W, H), (0, 0, 0)), bg, sh)
d = ImageDraw.Draw(bg)
d.rounded_rectangle([PX-4, PY-4, PX+PW+4, PY+PH+4], 104, fill=(58, 64, 78))   # rim
d.rounded_rectangle([PX, PY, PX+PW, PY+PH], 100, fill=(10, 11, 14))           # body
screen_mask = Image.new('L', (SW, SH), 0)
ImageDraw.Draw(screen_mask).rounded_rectangle([0, 0, SW-1, SH-1], 78, fill=255)

cache = {}
def screen(name):
    if name not in cache:
        cache[name] = Image.open(f'{SRC}/{name}').convert('RGB')
        if len(cache) > 6:
            cache.pop(next(iter(cache)))
    return cache[name]

# ---------- timeline in seconds ----------
INTRO, OUTRO, XF = 1.2, 1.8, 0.14
events = []          # (start, end, entry_index)
t = INTRO
for i, e in enumerate(tl):
    events.append((t, t + e['hold'], i))
    t += e['hold']
TOTAL = t + OUTRO
press_starts = [s for (s, _, i) in events
                if tl[i]['kind'] == 'down' and (i == 0 or tl[i-1]['kind'] != 'down')]
type_ticks = [s for (s, _, i) in events if tl[i]['kind'] == 'typing']

def ease(x):
    x = max(0.0, min(1.0, x))
    return x*x*(3 - 2*x)

def finger_at(time):
    """(x, y, pressed, alpha) in screen coordinates."""
    last = None
    for k, (s, e, i) in enumerate(events):
        f = tl[i]
        if f['x'] is not None:
            pos = (f['x'], f['y'])
        else:
            pos = None
        if s <= time < e:
            prev = None
            for j in range(k-1, -1, -1):
                pf = tl[events[j][2]]
                if pf['x'] is not None:
                    prev = (pf['x'], pf['y']); break
            if pos is None:
                p = prev or (SW*0.7, SH*0.8)
                return p[0], p[1], False, max(0.0, 1 - (time - s)/0.3)
            if f['kind'] in ('approach', 'swipe') and prev is not None:
                k2 = ease((time - s)/(e - s))
                x = prev[0] + (pos[0]-prev[0])*k2
                y = prev[1] + (pos[1]-prev[1])*k2
                return x, y, f['kind'] == 'swipe', 1.0
            return pos[0], pos[1], f['press'], 1.0
    return None

def frame_img(time):
    # which entry
    cur = None
    for (s, e, i) in events:
        if s <= time < e:
            cur = (s, i); break
    if time < INTRO:
        cur = (0, 0)
    if cur is None:
        cur = (events[-1][0], events[-1][2])
    s, i = cur
    img = screen(tl[i]['img'])
    if i > 0 and time - s < XF and tl[i-1]['img'] != tl[i]['img']:
        img = Image.blend(screen(tl[i-1]['img']), img, ease((time - s)/XF))
    return img.copy()

def draw_finger(scr, time):
    fa = finger_at(time) if INTRO <= time < TOTAL - OUTRO else None
    over = Image.new('RGBA', scr.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    # ripples from presses
    for ps in press_starts:
        dt = time - ps
        if 0 <= dt < 0.55:
            # ripple at the press position
            p = finger_at(ps + 0.01)
            if p:
                r = 40 + 150*ease(dt/0.55)
                a = int(150*(1 - dt/0.55))
                d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], outline=(255, 255, 255, a), width=6)
    if fa:
        x, y, pressed, alpha = fa
        # typing pulse
        pulse = 0.0
        for tt in type_ticks:
            if 0 <= time - tt < 0.12:
                pulse = 1 - (time - tt)/0.12
        r = 46 * (0.82 if pressed else 1.0) * (1 - 0.12*pulse)
        a = int(alpha*255)
        # soft shadow
        d.ellipse([x-r+6, y-r+10, x+r+6, y+r+10], fill=(0, 0, 0, int(a*0.25)))
        d.ellipse([x-r, y-r, x+r, y+r], fill=(255, 255, 255, int(a*(0.55 if pressed else 0.38))),
                  outline=(255, 255, 255, int(a*0.9)), width=4)
        d.ellipse([x-10, y-10, x+10, y+10], fill=(255, 255, 255, int(a*0.9)))
    over = over.filter(ImageFilter.GaussianBlur(0.8))
    scr.paste(over, (0, 0), over)
    return scr

proc = subprocess.Popen(
    ['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
     '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
     '-c:v', 'libx264', '-preset', 'faster', '-crf', '18', '-pix_fmt', 'yuv420p',
     '-movflags', '+faststart', '-tag:v', 'avc1', OUT], stdin=subprocess.PIPE)
N = int(TOTAL*FPS)
for n in range(N):
    time = n / FPS
    scr = draw_finger(frame_img(time), time)
    frame = bg.copy()
    frame.paste(scr, (SX, SY), screen_mask)
    # fade in / out
    if time < 0.6 or time > TOTAL - 0.8:
        k = min(time/0.6, (TOTAL - time)/0.8)
        frame = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), frame, max(0, min(1, k)))
    proc.stdin.write(frame.tobytes())
    if n % 150 == 0:
        print(f'{n}/{N}', flush=True)
proc.stdin.close(); proc.wait()
print('DONE', round(TOTAL, 1), 's')
