"""Synthesised soundtrack for the promo video — no samples, no licences:
a calm "space" ambient score plus robot sounds (thinking chirps, taps,
typing ticks, confirmations, whooshes) placed at the video's events.
Usage: python3 tools/video/make_promo_audio.py <events.json> <out.wav>
events.json: {"duration": seconds, "events": [{"t": s, "type": name}, ...]}
"""
import json, sys, wave
import numpy as np

SR = 48000
rng = np.random.default_rng(7)
spec = json.load(open(sys.argv[1]))
DUR = float(spec['duration'])
N = int(DUR * SR)
t_all = np.arange(N) / SR


def note_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env_adsr(n, a, r):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na:
        e[:na] = np.linspace(0, 1, na) ** 2
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e


def att(x, a=0.006):
    """Soft attack so tones never click."""
    return np.minimum(1, x / a)


def add(buf, start_s, sig):
    i = int(start_s * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def delay_verb(x, taps=((0.031, .5), (0.047, .42), (0.071, .35), (0.113, .28),
                        (0.173, .22), (0.257, .17), (0.389, .12), (0.577, .08))):
    """Cheap diffuse reverb: many decaying echoes, applied twice."""
    y = x.copy()
    for _ in range(2):
        z = y.copy()
        for d, g in taps:
            k = int(d * SR)
            z[k:] += g * y[:-k]
        y = z / 2.2
    return y


def lowpass(x, cutoff):
    """FFT low-pass (zero phase), fine for offline rendering."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


# ---------------- music ----------------
L = np.zeros(N)
R = np.zeros(N)

# Pad: Am9 → Fmaj7 → Cmaj7 → G6, 8 s each, additive detuned partials.
chords = [[57, 60, 64, 67, 71], [53, 57, 60, 64, 69], [48, 55, 59, 64, 67],
          [55, 59, 62, 64, 71]]
BAR = 8.0
k = 0
start = 0.0
while start < DUR:
    ch = chords[k % 4]
    n = int((BAR + 3.0) * SR)
    tt = np.arange(n) / SR
    sig_l = np.zeros(n)
    sig_r = np.zeros(n)
    for m in ch:
        f0 = note_hz(m)
        for p in range(1, 6):
            amp = 0.05 / p ** 1.6
            for det, side in ((-4, 0), (4, 1)):
                f = f0 * p * 2 ** (det / 1200)
                ph = rng.uniform(0, 2 * np.pi)
                trem = 1 + 0.25 * np.sin(2 * np.pi * rng.uniform(0.07, 0.2) * tt + ph)
                s = amp * trem * np.sin(2 * np.pi * f * tt + ph)
                (sig_l if side == 0 else sig_r)[:] += s
    e = env_adsr(n, 2.5, 3.0)
    add(L, start, sig_l * e)
    add(R, start, sig_r * e)
    start += BAR
    k += 1

# Sub drone with slow swell.
sub = 0.10 * np.sin(2 * np.pi * note_hz(33) * t_all) * (0.6 + 0.4 * np.sin(2 * np.pi * t_all / 16))
L += sub
R += sub

# Shimmering "stars": sparse pentatonic bells in the high register.
penta = [81, 83, 86, 88, 90, 93, 95, 98]
tt = 0.5
while tt < DUR - 1:
    m = penta[rng.integers(len(penta))]
    n = int(2.5 * SR)
    x = np.arange(n) / SR
    s = 0.035 * np.sin(2 * np.pi * note_hz(m) * x) * np.exp(-x * 2.2) * att(x, 0.02)
    s += 0.012 * np.sin(2 * np.pi * note_hz(m) * 2.01 * x) * np.exp(-x * 4) * att(x, 0.02)
    pan = rng.uniform(0.2, 0.8)
    add(L, tt, s * (1 - pan))
    add(R, tt, s * pan)
    tt += rng.uniform(0.6, 1.8)

# Soft pulse once the app is on screen: gentle arpeggio, 96 bpm eighths.
app_start = float(spec.get('pulse_from', 0))
app_end = float(spec.get('pulse_to', DUR))
step = 60 / 96 / 2
i = 0
tt = app_start
while tt < app_end:
    ch = chords[int(tt // BAR) % 4]
    m = ch[[0, 2, 4, 3][i % 4]] + 12
    n = int(0.6 * SR)
    x = np.arange(n) / SR
    s = 0.03 * np.sin(2 * np.pi * note_hz(m) * x) * np.exp(-x * 7) * att(x, 0.008)
    fade = min(1, (tt - app_start) / 4, (app_end - tt) / 3)
    pan = 0.35 if i % 2 else 0.65
    add(L, tt, s * fade * (1 - pan))
    add(R, tt, s * fade * pan)
    tt += step
    i += 1

L = delay_verb(L)
R = delay_verb(R[::-1])[::-1] * 0 + delay_verb(R)  # decorrelated enough
# Gentle overall fade in/out.
fade = np.minimum(1, np.minimum(t_all / 3.0, (DUR - t_all) / 4.0))
L *= fade
R *= fade

# ---------------- robot sounds ----------------
SL = np.zeros(N)
SR_ = np.zeros(N)


def chirp(f_a, f_b, dur, amp=0.12, wave_='sine'):
    n = int(dur * SR)
    x = np.arange(n) / SR
    f = np.geomspace(f_a, f_b, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) if wave_ == 'sine' else np.sign(np.sin(ph)) * 0.5
    return amp * s * env_adsr(n, 0.004, dur * 0.4)


def think(dur=1.2):
    """Robot 'thinking': a babble of quick pitch glides and data blips."""
    out = np.zeros(int((dur + 0.3) * SR))
    tt = 0.0
    while tt < dur:
        d = rng.uniform(0.035, 0.09)
        a, b = rng.uniform(600, 2400), rng.uniform(500, 2800)
        s = chirp(a, b, d, amp=rng.uniform(0.04, 0.08),
                  wave_='square' if rng.random() < 0.3 else 'sine')
        add_arr(out, tt, s)
        tt += d * rng.uniform(0.8, 1.6)
    return lowpass(out, 5000)


def add_arr(buf, start_s, sig):
    i = int(start_s * SR)
    j = min(len(buf), i + len(sig))
    if i < j:
        buf[i:j] += sig[: j - i]


def tap():
    n = int(0.06 * SR)
    x = np.arange(n) / SR
    s = 0.16 * np.sin(2 * np.pi * 1750 * x) * np.exp(-x * 90)
    s += 0.05 * rng.standard_normal(n) * np.exp(-x * 400)
    return s


def tick():
    n = int(0.03 * SR)
    x = np.arange(n) / SR
    return 0.05 * np.sin(2 * np.pi * rng.uniform(2600, 3200) * x) * np.exp(-x * 220)


def ding():
    n = int(1.6 * SR)
    x = np.arange(n) / SR
    s = 0.10 * np.sin(2 * np.pi * 1318.5 * x) * np.exp(-x * 3) * att(x, 0.004)
    s2 = np.zeros(n)
    k = int(0.09 * SR)
    s2[k:] = 0.09 * np.sin(2 * np.pi * 1975.5 * x[:-k]) * np.exp(-x[:-k] * 3) * att(x[:-k], 0.004)
    return s + s2


def whoosh(dur=0.9):
    n = int(dur * SR)
    x = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # Band sweep: blend of low-passed versions as the cutoff rises.
    lo = lowpass(noise, 600)
    hi = lowpass(noise, 4500)
    k = np.sin(np.pi * x / dur)
    s = (lo * (1 - x / dur) + hi * (x / dur)) * k ** 2
    return 0.12 * s / np.max(np.abs(s))


def sparkle(dur=1.5):
    """Papers dissolving into particles: rising glittery tones."""
    out = np.zeros(int((dur + 1) * SR))
    for i in range(28):
        tt = dur * i / 28 + rng.uniform(0, 0.03)
        m = 84 + int(rng.integers(0, 14)) + i // 3
        n = int(0.5 * SR)
        x = np.arange(n) / SR
        add_arr(out, tt, 0.03 * np.sin(2 * np.pi * note_hz(m) * x) * np.exp(-x * 9) * att(x))
    return out


makers = {'tap': tap, 'type': tick, 'ding': ding, 'whoosh': whoosh,
          'think': think, 'sparkle': sparkle}
for ev in spec['events']:
    s = makers[ev['type']]()
    pan = ev.get('pan', 0.5)
    add(SL, ev['t'], s * (1 - pan) * 2 * 0.7)
    add(SR_, ev['t'], s * pan * 2 * 0.7)

SL = SL + 0.35 * delay_verb(SL)
SR_ = SR_ + 0.35 * delay_verb(SR_)

mixL = L * 0.9 + SL
mixR = R * 0.9 + SR_
peak = max(np.max(np.abs(mixL)), np.max(np.abs(mixR)))
g = 0.89 / peak
out = np.stack([mixL * g, mixR * g], axis=1)
pcm = (np.clip(out, -1, 1) * 32767).astype('<i2')
with wave.open(sys.argv[2], 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print('AUDIO', round(DUR, 1), 's')
