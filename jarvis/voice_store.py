"""Новые голоса из интернета: каталог Джарвиса на GitHub, свежие голоса Microsoft и офлайн-голоса Piper.

Установленные голоса хранятся в voices/installed.json и добавляются в конец списка
(«голос номер …»), не сдвигая номера встроенных.
"""
import asyncio
import difflib
import json
import os
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
INSTALLED = os.path.join(HERE, "voices", "installed.json")
LOCAL_CATALOG = os.path.join(HERE, "voices", "catalog.json")
PIPER_DIR = os.path.join(HERE, "voices", "piper")
CATALOG_URL = ("https://raw.githubusercontent.com/sofley/blabla/"
               "claude/confident-brown-r8uh4o/jarvis/voices/catalog.json")
PIPER_URL = ("https://huggingface.co/rhasspy/piper-voices/resolve/main/"
             "{family}/{code}/{name}/{quality}/{model}{ext}?download=true")

# Короткие имена голосов Microsoft, которые читают по-русски
EDGE_NAMES_RU = {"Dmitry": "Дмитрий", "Svetlana": "Светлана", "Dariya": "Дарья"}


def load_installed():
    try:
        with open(INSTALLED, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def save_installed(items):
    os.makedirs(os.path.dirname(INSTALLED), exist_ok=True)
    with open(INSTALLED, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, indent=2)


def _key(p):
    return (p.get("engine"), p.get("voice") or p.get("model") or p.get("voice_id"), p.get("pitch"), p.get("rate"))


def fetch_catalog():
    """Каталог с GitHub; без интернета — локальная копия."""
    try:
        with urllib.request.urlopen(CATALOG_URL, timeout=20) as r:
            return json.loads(r.read().decode("utf-8")).get("voices", [])
    except Exception as e:
        print("[каталог голосов недоступен:", e, "— беру локальный]")
        try:
            with open(LOCAL_CATALOG, encoding="utf-8") as f:
                return json.load(f).get("voices", [])
        except (OSError, ValueError):
            return []


def fetch_edge_voices():
    """Все голоса Microsoft, которые умеют говорить по-русски: русские и многоязычные."""
    try:
        import edge_tts
        voices = asyncio.run(edge_tts.list_voices())
    except Exception as e:
        print("[список голосов Microsoft недоступен:", e, "]")
        return []
    out = []
    for v in voices:
        short = v.get("ShortName", "")
        if not (short.startswith("ru-") or "Multilingual" in short):
            continue
        base = short.split("-")[-1].replace("MultilingualNeural", "").replace("Neural", "")
        name = EDGE_NAMES_RU.get(base, base)
        accent = "" if short.startswith("ru-") else f" ({short[:5]}, с акцентом)"
        out.append({"name": f"{name}{accent}", "engine": "edge", "voice": short, "rate": "+0%", "pitch": "+0Hz",
                    "gender": v.get("Gender", "")})
    return out


def discover(builtin):
    """Находит голоса, которых ещё нет у Джарвиса, и устанавливает их. Возвращает список новых."""
    have = {_key(p) for p in builtin} | {_key(p) for p in load_installed()}
    have_edge = {p.get("voice") for p in builtin + load_installed() if p.get("engine") == "edge"}
    new = []
    for p in fetch_catalog():
        if _key(p) not in have:
            new.append(p)
            have.add(_key(p))
    for p in fetch_edge_voices():
        if p["voice"] not in have_edge:
            new.append(p)
            have_edge.add(p["voice"])
    if new:
        save_installed(load_installed() + new)
    return new


def search_online(query, builtin):
    """Ищет голос по имени («Денис», «Андрей»…) среди каталога и голосов Microsoft."""
    query = query.lower().replace("ё", "е").strip()
    cands = fetch_catalog() + fetch_edge_voices()
    best, score = None, 0.0
    for p in cands:
        for n in (p["name"].lower().split(" (")[0], (p.get("voice") or p.get("model") or "").lower()):
            n = n.replace("ё", "е")
            s = 1.0 if query in n else difflib.SequenceMatcher(None, query, n).ratio()
            if s > score:
                best, score = p, s
    if not best or score < .6:
        return None
    installed = load_installed()
    for p in builtin + installed:
        if _key(p) == _key(best):
            return p
    save_installed(installed + [best])
    return best


# ---------------------------------------------------------------- Piper (офлайн)
def piper_paths(model):
    return os.path.join(PIPER_DIR, model + ".onnx"), os.path.join(PIPER_DIR, model + ".onnx.json")


def ensure_piper_model(model, say=None):
    """Скачивает модель Piper (около 60 МБ) при первом использовании."""
    onnx, cfg = piper_paths(model)
    if os.path.exists(onnx) and os.path.exists(cfg):
        return onnx
    if say:
        say("Скачиваю этот голос, около минуты.")
    code, name, quality = model.split("-", 2)
    os.makedirs(PIPER_DIR, exist_ok=True)
    for ext, dst in ((".onnx.json", cfg), (".onnx", onnx)):
        url = PIPER_URL.format(family=code.split("_")[0], code=code, name=name, quality=quality, model=model, ext=ext)
        tmp = dst + ".part"
        urllib.request.urlretrieve(url, tmp)
        os.replace(tmp, dst)
    return onnx


_piper_cache = {}


def piper_synth(model, text, wav_path, rate=1.0):
    import wave
    from piper import PiperVoice, SynthesisConfig
    onnx, cfg = piper_paths(model)
    voice = _piper_cache.get(model)
    if voice is None:
        voice = _piper_cache[model] = PiperVoice.load(onnx, config_path=cfg)
    with wave.open(wav_path, "wb") as wf:
        voice.synthesize_wav(text, wf, syn_config=SynthesisConfig(length_scale=1.0 / max(.5, float(rate))))
