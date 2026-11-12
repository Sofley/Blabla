"""NexusTrade promo video (no voice-over): robot-assistant scenes made
alive (camera moves, particles, light) + the REAL app recorded by
test/tools/promo_tool_test.dart with an animated finger, captions and
camera zooms. Writes video.mp4 (silent) and events.json for
make_promo_audio.py, then muxes the final file.
Usage: python3 tools/video/make_promo.py <frames_dir> <robot.png> <lang> <out.mp4>
"""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC, ROBOT, LANG, OUT = sys.argv[1:5]
W, H, FPS = 1920, 1080, 60
ROOT = os.path.dirname(os.path.abspath(__file__)) + '/../..'
GOLD = (232, 186, 92)
NAVY = (6, 12, 28)

FONT_R = f'{ROOT}/assets/fonts/Roboto-Regular.ttf'
FONT_B = f'{ROOT}/assets/fonts/Roboto-Bold.ttf'
if LANG == 'zh':
    FONT_R = FONT_B = f'{ROOT}/assets/fonts/NotoSansSC-Regular.ttf'

TEXT = {
    'ru': {
        'chaos1': ('ЗНАКОМО?', 'Тетради, стикеры, таблицы…'),
        'chaos2': ('', 'Сделки разбросаны. Время уходит.'),
        'idea': ('', 'А если всё это — в одном телефоне?'),
        'dashboard': ('ГЛАВНАЯ', 'Итоги месяца —\nс первого взгляда'),
        'new_deal': ('НОВАЯ СДЕЛКА', 'Пустые поля\nзаполняются на глазах'),
        'price': ('КОНТРАКТ №1', 'Покупатель, товар и цена —\nза пару касаний'),
        'contract2': ('КОНТРАКТ №2', 'Закупка у завода'),
        'logistics': ('ЛОГИСТИКА', 'Фура или контейнер —\nрасчёт сам'),
        'summary': ('ИТОГ', 'Чистая прибыль —\nсразу, без калькулятора'),
        'stages': ('ЭТАПЫ', 'Каждый шаг сделки\nпод контролем'),
        'documents': ('ДОКУМЕНТЫ', 'Договор — в досье сделки,\nа не в ящике стола'),
        'dashboard_end': ('ВСЁ В ОДНОМ МЕСТЕ', 'Сделки · Контракты\nДокументы · Финансы'),
        'outro1': ('', 'Меньше бумаг.'),
        'outro2': ('', 'Больше времени для главного.'),
        'slogan': 'Торгуйте уверенно.',
        'thinking': 'анализирую…',
    },
    'en': {
        'chaos1': ('SOUND FAMILIAR?', 'Notebooks, sticky notes, spreadsheets…'),
        'chaos2': ('', 'Deals scattered. Time slipping away.'),
        'idea': ('', 'What if it all fit in one phone?'),
        'dashboard': ('HOME', 'Your month\nat a glance'),
        'new_deal': ('NEW DEAL', 'Empty fields\nfill in before your eyes'),
        'price': ('CONTRACT #1', 'Buyer, product and price —\nin a few taps'),
        'contract2': ('CONTRACT #2', 'Purchase from the factory'),
        'logistics': ('LOGISTICS', 'Truck or container —\ncalculated for you'),
        'summary': ('SUMMARY', 'Net profit —\ninstantly, no calculator'),
        'stages': ('STAGES', 'Every step of the deal\nunder control'),
        'documents': ('DOCUMENTS', 'The contract lives in the deal file,\nnot in a desk drawer'),
        'dashboard_end': ('ALL IN ONE PLACE', 'Deals · Contracts\nDocuments · Finance'),
        'outro1': ('', 'Less paper.'),
        'outro2': ('', 'More time for what matters.'),
        'slogan': 'Trade with confidence.',
        'thinking': 'analyzing…',
    },
    'zh': {
        'chaos1': ('似曾相识？', '笔记本、便签、表格……'),
        'chaos2': ('', '交易信息分散，时间悄悄流逝。'),
        'idea': ('', '如果这一切都在一部手机里呢？'),
        'dashboard': ('首页', '本月业绩\n一目了然'),
        'new_deal': ('新建交易', '空白字段\n即时填写'),
        'price': ('合同一', '买方、商品和价格——\n轻点几下即可'),
        'contract2': ('合同二', '向工厂采购'),
        'logistics': ('物流', '卡车或集装箱——\n自动计算'),
        'summary': ('汇总', '净利润——\n即时呈现，无需计算器'),
        'stages': ('阶段', '交易每一步\n尽在掌握'),
        'documents': ('文件', '合同归入交易档案，\n不再锁在抽屉里'),
        'dashboard_end': ('一站式管理', '交易 · 合同\n文件 · 财务'),
        'outro1': ('', '更少纸张。'),
        'outro2': ('', '更多时间留给重要的事。'),
        'slogan': '自信交易。',
        'thinking': '分析中…',
    },
}[LANG]

rng = np.random.default_rng(3)
events = []  # audio cues


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def font(path, size):
    return ImageFont.truetype(path, size)


F_LABEL = font(FONT_B, 26)
F_BIG = font(FONT_B, 58)
F_MID = font(FONT_R, 44)

# ---------------- shared backgrounds ----------------
def make_bg():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((x - W * 0.62) / (W * 0.7)) ** 2 + ((y - H * 0.5) / (H * 0.8)) ** 2)
    k = np.clip(1 - d, 0, 1)[..., None]
    base = np.array(NAVY, np.float32)
    glow = np.array((22, 50, 105), np.float32)
    img = base * (1 - k) + glow * k
    return Image.fromarray(img.astype(np.uint8))


BG = make_bg()
STARS = [(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.6, 2.2),
          rng.uniform(4, 18), rng.uniform(0, 6.28)) for _ in range(170)]


def draw_stars(img, t, alpha=1.0):
    over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for x, y, r, sp, ph in STARS:
        xx = (x - t * sp) % W
        a = int(alpha * (90 + 90 * math.sin(t * 1.3 + ph)))
        col = (255, 226, 160, a) if r > 1.8 else (200, 220, 255, a)
        d.ellipse([xx - r, y - r, xx + r, y + r], fill=col)
    img.paste(over, (0, 0), over)


def caption(img, key, t_in, t, t_out, x=150, y=None, align='left'):
    """Gold label + white text, slides in, fades out."""
    if t < t_in or t > t_out:
        return
    label, text = TEXT[key]
    a = ease((t - t_in) / 0.5) * (1 - ease((t - (t_out - 0.4)) / 0.4))
    dy = (1 - ease((t - t_in) / 0.6)) * 30
    over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    big = F_BIG if '\n' in text or len(text) < 34 else F_MID
    bbox = d.multiline_textbbox((0, 0), text, font=big, spacing=14)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    yy = (H - th) / 2 if y is None else y
    xx = x if align == 'left' else (W - tw) / 2
    if label:
        d.text((xx, yy - 52 + dy), label, font=F_LABEL, fill=GOLD + (int(255 * a),))
        d.rectangle([xx, yy - 14 + dy, xx + 60, yy - 10 + dy], fill=GOLD + (int(255 * a),))
    # soft shadow
    sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).multiline_text((xx + 3, yy + 4 + dy), text, font=big,
                                      fill=(0, 0, 0, int(160 * a)), spacing=14,
                                      align=align)
    sh = sh.filter(ImageFilter.GaussianBlur(6))
    img.paste(sh, (0, 0), sh)
    d.multiline_text((xx, yy + dy), text, font=big, fill=(255, 255, 255, int(255 * a)),
                     spacing=14, align=align)
    img.paste(over, (0, 0), over)


# ---------------- robot scenes ----------------
robot_src = Image.open(ROBOT).convert('RGB')
RW, RH = robot_src.size  # 1280 x 720
robot_big = robot_src.resize((RW * 2, RH * 2), Image.LANCZOS)
S2 = 2.0  # robot_big px per source px

PHONE_SRC = (690, 330)  # phone in the robot picture (source px)
PAPERS = (40, 40, 470, 430)


def kenburns(cx, cy, zoom):
    """Crop of the robot picture centred on (cx, cy) source px; zoom=1 → full."""
    cw, ch = RW / zoom, RH / zoom
    x0 = min(max(cx - cw / 2, 0), RW - cw)
    y0 = min(max(cy - ch / 2, 0), RH - ch)
    box = [int(x0 * S2), int(y0 * S2), int((x0 + cw) * S2), int((y0 + ch) * S2)]
    img = robot_big.crop(box).resize((W, H), Image.BILINEAR)
    to_out = lambda px, py: ((px - x0) / cw * W, (py - y0) / ch * H)
    return img, to_out


PARTS = [(rng.uniform(PAPERS[0], PAPERS[2]), rng.uniform(PAPERS[1], PAPERS[3]),
          rng.uniform(0, 1), rng.uniform(0.25, 0.5), rng.uniform(-90, 60))
         for _ in range(260)]


def particles(img, to_out, t, strength):
    if strength <= 0:
        return
    over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for sx, sy, off, sp, bend in PARTS:
        p = (t * sp + off) % 1.0
        cx, cy = (sx + PHONE_SRC[0]) / 2, min(sy, PHONE_SRC[1]) + bend
        x = (1 - p) ** 2 * sx + 2 * (1 - p) * p * cx + p * p * PHONE_SRC[0]
        y = (1 - p) ** 2 * sy + 2 * (1 - p) * p * cy + p * p * PHONE_SRC[1]
        ox, oy = to_out(x, y)
        r = 1.5 + 3.5 * (1 - p)
        a = int(strength * 230 * math.sin(math.pi * p))
        d.ellipse([ox - r * 2.2, oy - r * 2.2, ox + r * 2.2, oy + r * 2.2],
                  fill=(255, 190, 80, a // 5))
        d.ellipse([ox - r, oy - r, ox + r, oy + r], fill=(255, 225, 150, a))
    over = over.filter(ImageFilter.GaussianBlur(0.7))
    img.paste(over, (0, 0), over)


def phone_glow(img, to_out, a):
    if a <= 0:
        return
    ox, oy = to_out(*PHONE_SRC)
    over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for r, al in ((220, 30), (130, 60), (70, 90)):
        d.ellipse([ox - r, oy - r * 1.3, ox + r, oy + r * 1.3], fill=(255, 220, 140, int(al * a)))
    over = over.filter(ImageFilter.GaussianBlur(40))
    img.paste(over, (0, 0), over)


def vignette(img, k=0.55):
    v = Image.new('L', (W, H), 0)
    ImageDraw.Draw(v).ellipse([-W * 0.15, -H * 0.2, W * 1.15, H * 1.2], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(160))
    dark = Image.new('RGB', (W, H), (0, 0, 0))
    return Image.composite(img, Image.blend(dark, img, 1 - k), v)


VIG_MASK = None


def darken_left(img, amount):
    global VIG_MASK
    if VIG_MASK is None:
        g = np.clip(1 - np.linspace(0, 1, W) * 1.6, 0, 1) ** 1.2
        VIG_MASK = Image.fromarray((np.tile(g, (H, 1)) * 255).astype(np.uint8))
    dark = Image.new('RGB', (W, H), NAVY)
    return Image.composite(Image.blend(img, dark, amount), img, VIG_MASK)


# robot head avatar for the app section ("the robot is thinking")
HEAD = robot_src.crop((800, 60, 1040, 300)).resize((150, 150), Image.LANCZOS)
HM = Image.new('L', (150, 150), 0)
ImageDraw.Draw(HM).ellipse([0, 0, 149, 149], fill=255)

# ---------------- app section ----------------
tl = json.load(open(f'{SRC}/timeline.json'))
marks = {}
entries = []
for e in tl:
    if e['kind'] == 'mark':
        marks[len(entries)] = e['scene']
    else:
        entries.append(e)

screen0 = Image.open(f'{SRC}/{entries[0]["img"]}').convert('RGB')
SW, SH = screen0.size  # 864 x 1920
BASE_SCALE = 0.47
PHONE_CX = 1300

cache = {}


def screen(name):
    if name not in cache:
        cache[name] = Image.open(f'{SRC}/{name}').convert('RGB')
        if len(cache) > 8:
            cache.pop(next(iter(cache)))
    return cache[name]


# timing of the app section
app = []
t = 0.0
scene_at = {}
for i, e in enumerate(entries):
    if i in marks:
        scene_at[marks[i]] = t
    hold = e['hold']
    app.append((t, t + hold, i))
    t += hold
APP_DUR = t + 0.6
scene_list = sorted(scene_at.items(), key=lambda kv: kv[1])

# camera zoom per scene: (zoom, focus_y as share of screen height)
ZOOMS = {'summary': (1.55, 0.27), 'documents': (1.45, 0.50), 'stages': (1.25, 0.45)}


def scene_of(t):
    cur = scene_list[0][0]
    for name, st in scene_list:
        if t >= st:
            cur = name
    return cur


def scene_end(name):
    names = [n for n, _ in scene_list]
    i = names.index(name)
    return scene_list[i + 1][1] if i + 1 < len(names) else APP_DUR


def camera(t):
    z, fy = 1.0, 0.5
    for name, (zz, ffy) in ZOOMS.items():
        if name not in scene_at:
            continue
        st, en = scene_at[name], scene_end(name)
        if name == 'summary':
            st += 1.0  # after the tab opens
        k = ease((t - st) / 0.9) * (1 - ease((t - (en - 0.6)) / 0.6))
        if k > 0:
            z = 1 + (zz - 1) * k
            fy = 0.5 + (ffy - 0.5) * k
    return z, fy


def entry_at(t):
    for s, e, i in app:
        if s <= t < e:
            return s, i
    return app[-1][0], app[-1][2]


def finger(t):
    s, i = entry_at(t)
    e = entries[i]
    if e['x'] is None:
        return None
    if e['kind'] == 'approach':
        prev = None
        for j in range(i - 1, -1, -1):
            if entries[j]['x'] is not None:
                prev = (entries[j]['x'], entries[j]['y'])
                break
        if prev:
            k = ease((t - s) / e['hold'])
            return (prev[0] + (e['x'] - prev[0]) * k,
                    prev[1] + (e['y'] - prev[1]) * k, False)
    return e['x'], e['y'], e['press']


press_times = [s for (s, _, i) in app
               if entries[i]['kind'] == 'down' and entries[i - 1]['kind'] != 'down']
type_times = [s for (s, _, i) in app if entries[i]['kind'] == 'typing']
attach_times = [s for (s, _, i) in app if entries[i]['kind'] == 'attached']

SCR_MASK = Image.new('L', (SW, SH), 0)
ImageDraw.Draw(SCR_MASK).rounded_rectangle([0, 0, SW - 1, SH - 1], 70, fill=255)


def app_frame(t, intro_k=1.0):
    img = BG.copy()
    draw_stars(img, t)
    s, i = entry_at(t)
    scr = screen(entries[i]['img']).copy()
    if i > 0 and t - s < 0.08 and entries[i - 1]['img'] != entries[i]['img'] \
            and entries[i]['kind'] != 'swipe' and entries[i - 1]['kind'] != 'swipe':
        scr = Image.blend(screen(entries[i - 1]['img']), scr, ease((t - s) / 0.08))
    # finger + ripples on the screen
    over = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for ps in press_times:
        dt = t - ps
        if 0 <= dt < 0.55:
            _, pi = entry_at(ps + 0.001)
            px, py = entries[pi]['x'], entries[pi]['y']
            r = 40 + 150 * ease(dt / 0.55)
            a = int(170 * (1 - dt / 0.55))
            d.ellipse([px - r, py - r, px + r, py + r], outline=(255, 214, 140, a), width=7)
    f = finger(t)
    if f:
        x, y, pressed = f
        pulse = max([1 - (t - tt) / 0.1 for tt in type_times if 0 <= t - tt < 0.1] or [0])
        r = 48 * (0.82 if pressed else 1.0) * (1 - 0.12 * pulse)
        d.ellipse([x - r + 6, y - r + 10, x + r + 6, y + r + 10], fill=(0, 0, 0, 60))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 236, 200, 150 if pressed else 95),
                  outline=(255, 214, 140, 230), width=4)
        d.ellipse([x - 10, y - 10, x + 10, y + 10], fill=(255, 245, 225, 235))
    scr.paste(over, (0, 0), over)

    z, fy = camera(t)
    sc = BASE_SCALE * z * (0.92 + 0.08 * intro_k)
    pw, ph = int(SW * sc), int(SH * sc)
    bez = int(14 * sc / BASE_SCALE)
    cx = PHONE_CX
    # focus point of the screen goes to the vertical centre
    cy = H / 2 - (fy - 0.5) * ph
    cy += math.sin(t * 0.8) * 4  # gentle float
    x0, y0 = int(cx - pw / 2), int(cy - ph / 2)
    body = Image.new('RGBA', (pw + bez * 2, ph + bez * 2), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, pw + bez * 2 - 1, ph + bez * 2 - 1],
                                           int(40 * sc / BASE_SCALE * 1.4),
                                           fill=(12, 14, 20, 255), outline=(70, 78, 96, 255),
                                           width=max(2, bez // 4))
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x0 - bez + 30, y0 - bez + 50, x0 + pw + bez + 30,
                                              y0 + ph + bez + 50], 60, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    img.paste(shadow, (0, 0), shadow)
    # gold rim light
    img.paste(body, (x0 - bez, y0 - bez), body)
    img.paste(scr.resize((pw, ph), Image.BILINEAR), (x0, y0),
              SCR_MASK.resize((pw, ph), Image.BILINEAR))
    # captions
    name = scene_of(t)
    if name in TEXT:
        caption(img, name, scene_at[name] + 0.2, t, scene_end(name) - 0.1, x=150)
    # robot avatar, "thinking" during new deal and summary
    think = 0.0
    for nm in ('new_deal', 'summary'):
        if nm in scene_at:
            st = scene_at[nm]
            think = max(think, ease((t - st) / 0.4) * (1 - ease((t - st - 2.6) / 0.4)))
    avatar(img, t, think)
    # success glow when the contract gets attached
    for at in attach_times:
        if 0 <= t - at < 1.2:
            g = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            k = 1 - (t - at) / 1.2
            ImageDraw.Draw(g).ellipse([cx - 420, H / 2 - 420, cx + 420, H / 2 + 420],
                                      fill=(255, 210, 120, int(60 * k)))
            g = g.filter(ImageFilter.GaussianBlur(80))
            img.paste(g, (0, 0), g)
    return img


def avatar(img, t, think):
    x, y = 150, H - 230
    ring = Image.new('RGBA', (190, 190), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    a = int(160 + 95 * think)
    d.ellipse([5, 5, 184, 184], outline=GOLD + (a,), width=4)
    if think > 0:
        g = Image.new('RGBA', (190, 190), (0, 0, 0, 0))
        ImageDraw.Draw(g).ellipse([0, 0, 189, 189], fill=(120, 190, 255, int(70 * think)))
        g = g.filter(ImageFilter.GaussianBlur(14))
        img.paste(g, (x - 20, y - 20), g)
    img.paste(HEAD, (x, y), HM)
    img.paste(ring, (x - 20, y - 20), ring)
    if think > 0.05:
        over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        dd = ImageDraw.Draw(over)
        for k in range(3):
            ph = math.sin(t * 7 - k * 0.8) * 0.5 + 0.5
            r = 6 + 3 * ph
            cx = x + 200 + k * 26
            dd.ellipse([cx - r, y + 75 - r, cx + r, y + 75 + r],
                       fill=(140, 200, 255, int(255 * think * (0.4 + 0.6 * ph))))
        dd.text((x + 280, y + 58), TEXT['thinking'], font=font(FONT_R, 28),
                fill=(170, 210, 255, int(220 * think)))
        img.paste(over, (0, 0), over)


# ---------------- logo ----------------
EMBLEM = Image.open(f'{ROOT}/assets/splash/emblem.png').convert('RGBA')
WORD = Image.open(f'{ROOT}/assets/splash/wordmark.png').convert('RGBA')


def logo_frame(t, dur):
    img = BG.copy()
    draw_stars(img, t + 40)
    k = ease(t / 1.2)
    sc = 0.55 * (0.9 + 0.1 * k)
    em = EMBLEM.resize((int(EMBLEM.width * sc), int(EMBLEM.height * sc)), Image.LANCZOS)
    a = em.split()[3].point(lambda v: int(v * k))
    em.putalpha(a)
    ex = (W - em.width) // 2
    ey = int(H * 0.40 - em.height / 2)
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W / 2 - 330, ey - 40, W / 2 + 330, ey + em.height + 40],
                                 fill=(255, 200, 110, int(45 * k)))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    img.paste(glow, (0, 0), glow)
    img.paste(em, (ex, ey), em)
    k2 = ease((t - 0.8) / 1.0)
    if k2 > 0:
        wsc = 0.62
        wm = WORD.resize((int(WORD.width * wsc), int(WORD.height * wsc)), Image.LANCZOS)
        wm.putalpha(wm.split()[3].point(lambda v: int(v * k2)))
        img.paste(wm, ((W - wm.width) // 2, ey + em.height + 30), wm)
    k3 = ease((t - 1.8) / 0.8)
    if k3 > 0:
        over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(over)
        f = font(FONT_R, 46)
        tw = d.textlength(TEXT['slogan'], font=f)
        d.text(((W - tw) / 2, ey + em.height + 150), TEXT['slogan'], font=f,
               fill=GOLD + (int(255 * k3),))
        img.paste(over, (0, 0), over)
    # sweeping light
    sweep = (t - 1.0) / 1.2
    if 0 < sweep < 1:
        over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        sx = -200 + sweep * (W + 400)
        ImageDraw.Draw(over).polygon([(sx, 0), (sx + 120, 0), (sx - 80, H), (sx - 200, H)],
                                     fill=(255, 255, 255, 28))
        over = over.filter(ImageFilter.GaussianBlur(30))
        img.paste(over, (0, 0), over)
    return img


# ---------------- storyboard ----------------
A, B, FLASH, OUT_R, LOGO = 6.5, 7.5, 0.7, 6.5, 5.5
T_APP0 = A + B + FLASH
T_OUT = T_APP0 + APP_DUR
TOTAL = T_OUT + OUT_R + LOGO

# audio cues
events.append({'t': 0.4, 'type': 'whoosh', 'pan': 0.3})
events.append({'t': A - 0.4, 'type': 'whoosh', 'pan': 0.6})
events.append({'t': A + 0.8, 'type': 'think', 'pan': 0.65})
events.append({'t': A + 1.5, 'type': 'sparkle', 'pan': 0.4})
events.append({'t': A + B - 0.5, 'type': 'whoosh'})
for name, st in scene_list:
    if st > 0.5:
        events.append({'t': T_APP0 + st, 'type': 'whoosh', 'pan': 0.6})
for nm in ('new_deal', 'summary'):
    if nm in scene_at:
        events.append({'t': T_APP0 + scene_at[nm] + 0.2, 'type': 'think', 'pan': 0.25})
for ps in press_times:
    events.append({'t': T_APP0 + ps, 'type': 'tap', 'pan': 0.62})
for tt in type_times:
    events.append({'t': T_APP0 + tt, 'type': 'type', 'pan': 0.62})
for at in attach_times:
    events.append({'t': T_APP0 + at, 'type': 'ding', 'pan': 0.6})
if 'stages' in scene_at:
    events.append({'t': T_APP0 + scene_at['stages'] - 0.3, 'type': 'ding', 'pan': 0.6})
events.append({'t': T_OUT, 'type': 'whoosh'})
events.append({'t': T_OUT + OUT_R + 0.9, 'type': 'ding'})

tmp = OUT + '.silent.mp4'
proc = subprocess.Popen(
    ['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
     '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
     '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p',
     '-movflags', '+faststart', tmp], stdin=subprocess.PIPE)

N = int(TOTAL * FPS)
for n in range(N):
    t = n / FPS
    if t < A:  # chaos: papers on the desk, slow drift right
        k = t / A
        img, to_out = kenburns(330 + 120 * k, 260, 1.9 - 0.15 * k)
        particles(img, to_out, t, 0.25 * k)
        img = vignette(img, 0.5)
        caption(img, 'chaos1', 0.6, t, 3.6, x=W * 0.52, y=H * 0.70)
        caption(img, 'chaos2', 3.7, t, A + 0.1, x=W * 0.52, y=H * 0.72)
    elif t < A + B:  # robot takes the phone, papers stream into it
        tb = t - A
        k = ease(tb / B)
        img, to_out = kenburns(640 + 60 * k, 360 - 10 * k, 1.0 + 0.55 * k)
        particles(img, to_out, t, min(1, tb / 1.2))
        phone_glow(img, to_out, ease((tb - 2) / 3))
        img = vignette(img, 0.45)
        caption(img, 'idea', 2.2, tb, B - 0.2, y=H * 0.80, align='center')
    elif t < T_APP0:  # flash into the phone
        tf = (t - A - B) / FLASH
        if tf < 0.5:
            img, to_out = kenburns(PHONE_SRC[0], PHONE_SRC[1], 1.55 + 3 * ease(tf * 2))
            img = Image.blend(img, Image.new('RGB', (W, H), (255, 236, 200)), ease(tf * 2))
        else:
            img = Image.blend(Image.new('RGB', (W, H), (255, 236, 200)), app_frame(0, 0),
                              ease((tf - 0.5) * 2))
    elif t < T_OUT:
        ta = t - T_APP0
        img = app_frame(ta, ease(ta / 1.0))
        if ta > APP_DUR - 0.5:
            img = Image.blend(img, Image.new('RGB', (W, H), (0, 0, 0)), ease((ta - APP_DUR + 0.5) / 0.5))
    elif t < T_OUT + OUT_R:  # robot relaxes: calm, clean desk feeling
        to = t - T_OUT
        k = ease(to / OUT_R)
        img, to_out = kenburns(900, 300, 1.6 - 0.25 * k)
        img = darken_left(img, 0.55)
        phone_glow(img, to_out, 0.6)
        caption(img, 'outro1', 0.6, to, OUT_R + 0.2, x=140, y=H * 0.38)
        caption(img, 'outro2', 2.0, to, OUT_R + 0.2, x=140, y=H * 0.52)
        if to < 0.6:
            img = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), img, ease(to / 0.6))
    else:
        tl_ = t - T_OUT - OUT_R
        img = logo_frame(tl_, LOGO)
        if tl_ < 0.5:
            img = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), img, ease(tl_ / 0.5))
        if tl_ > LOGO - 0.8:
            img = Image.blend(img, Image.new('RGB', (W, H), (0, 0, 0)), ease((tl_ - LOGO + 0.8) / 0.8))
    proc.stdin.write(img.convert('RGB').tobytes())
    if n % 600 == 0:
        print(f'{n}/{N}', flush=True)
proc.stdin.close()
proc.wait()

ev_path = OUT + '.events.json'
json.dump({'duration': TOTAL, 'events': events, 'pulse_from': T_APP0,
           'pulse_to': T_OUT}, open(ev_path, 'w'))
wav = OUT + '.wav'
subprocess.run([sys.executable, f'{os.path.dirname(__file__)}/make_promo_audio.py', ev_path, wav],
               check=True)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-i', wav, '-c:v', 'copy',
                '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', '-c:a', 'aac', '-b:a', '256k', '-shortest', '-movflags', '+faststart', OUT],
               check=True)
os.remove(tmp)
print('DONE', round(TOTAL, 1), 's')
