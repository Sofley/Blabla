"""Настройки Windows и файлы голосом: разделы «Параметров», тема, яркость, поиск и запуск файлов."""
import difflib
import os
import re
import string
import subprocess
import time

# Раздел «Параметров» Windows по ключевым словам
SETTINGS = [
    (["вай фай", "wifi", "wi fi", "вайфай", "интернет", "сеть", "сети"], "ms-settings:network-wifi", "Wi-Fi и сеть"),
    (["блютуз", "bluetooth", "блютус", "наушник"], "ms-settings:bluetooth", "Bluetooth"),
    (["звук", "динамик", "громкост"], "ms-settings:sound", "Звук"),
    (["микрофон"], "ms-settings:sound", "Звук и микрофон"),
    (["экран", "дисплей", "яркост", "разрешени"], "ms-settings:display", "Экран"),
    (["обновлен", "апдейт"], "ms-settings:windowsupdate", "Обновление Windows"),
    (["батаре", "питани", "энерг", "сон", "заряд"], "ms-settings:powersleep", "Питание и батарея"),
    (["мыш", "тачпад", "сенсорн"], "ms-settings:mousetouchpad", "Мышь и тачпад"),
    (["язык", "раскладк", "клавиатур"], "ms-settings:regionlanguage", "Язык и клавиатура"),
    (["дата", "время", "часов", "часы"], "ms-settings:dateandtime", "Дата и время"),
    (["приложени", "программ"], "ms-settings:appsfeatures", "Приложения"),
    (["автозагруз"], "ms-settings:startupapps", "Автозагрузка"),
    (["уведомлени"], "ms-settings:notifications", "Уведомления"),
    (["фон", "обои", "заставк"], "ms-settings:personalization-background", "Фон рабочего стола"),
    (["тем", "оформлени", "цвет", "персонализ"], "ms-settings:personalization-colors", "Цвета и тема"),
    (["принтер", "печат"], "ms-settings:printers", "Принтеры"),
    (["специальн", "доступност", "экранн", "диктор", "лупа"], "ms-settings:easeofaccess", "Специальные возможности"),
    (["памят", "хранилищ", "диск", "мест"], "ms-settings:storagesense", "Память устройства"),
    (["учетн", "аккаунт", "пароль", "вход"], "ms-settings:signinoptions", "Учётные записи и вход"),
    (["конфиденциальн", "камер", "разрешени"], "ms-settings:privacy", "Конфиденциальность"),
    (["режим полета", "режим самолет"], "ms-settings:network-airplanemode", "Режим «в самолёте»"),
    (["безопасност", "защитник", "антивирус"], "windowsdefender:", "Безопасность Windows"),
]


def settings_page(text):
    """Какой раздел «Параметров» просит человек. Возвращает (uri, название)."""
    for roots, uri, name in SETTINGS:
        if any(r in text for r in roots):
            return uri, name
    return "ms-settings:", "Параметры Windows"


def open_settings(uri):
    os.startfile(uri)


def set_theme(dark):
    """Тёмная или светлая тема Windows и приложений."""
    import winreg
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                         r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", 0, winreg.KEY_SET_VALUE)
    for name in ("AppsUseLightTheme", "SystemUsesLightTheme"):
        winreg.SetValueEx(key, name, 0, winreg.REG_DWORD, 0 if dark else 1)
    winreg.CloseKey(key)


def _ps(cmd):
    r = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True,
                       creationflags=0x08000000, timeout=15)
    return r.stdout.strip(), r.returncode


def get_brightness():
    out, code = _ps("(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness).CurrentBrightness")
    try:
        return int(out.splitlines()[0])
    except (ValueError, IndexError):
        return None


def set_brightness(level=None, delta=None):
    """Яркость встроенного экрана (ноутбук). На внешних мониторах Windows так менять не даёт."""
    cur = get_brightness()
    if cur is None:
        return None
    new = level if level is not None else cur + (delta or 0)
    new = max(5, min(100, int(new)))
    _, code = _ps(f"(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods)"
                  f" | Invoke-CimMethod -MethodName WmiSetBrightness -Arguments @{{Timeout=1; Brightness={new}}}")
    return new if code == 0 else None


# ---------------------------------------------------------------- файлы
TRANSLIT = str.maketrans({"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z",
                          "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r",
                          "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh",
                          "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya"})
SKIP_DIRS = {"windows", "program files", "program files (x86)", "programdata", "$recycle.bin", "appdata",
             "node_modules", ".git", ".venv", "venv", "__pycache__", "ollama_models", "ollama", "system volume information"}
DOC_HINT = {"документ": (".doc", ".docx", ".pdf", ".txt", ".rtf", ".odt"), "таблиц": (".xls", ".xlsx", ".csv", ".ods"),
            "презентац": (".ppt", ".pptx", ".pdf"), "фото": (".jpg", ".jpeg", ".png", ".heic", ".webp"),
            "картинк": (".jpg", ".jpeg", ".png", ".gif", ".webp"), "видео": (".mp4", ".mkv", ".avi", ".mov"),
            "музык": (".mp3", ".wav", ".flac", ".m4a"), "песн": (".mp3", ".wav", ".flac", ".m4a")}
RISKY_EXT = (".exe", ".bat", ".cmd", ".msi", ".ps1", ".vbs", ".js", ".reg", ".scr", ".lnk", ".com")


def _norm_name(s):
    s = s.lower().replace("ё", "е")
    s = re.sub(r"[_\-.()\[\]]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def search_roots(extra=()):
    home = os.path.expanduser("~")
    roots = [os.path.join(home, d) for d in ("Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos")]
    roots += [os.path.join(home, "OneDrive", d) for d in ("Desktop", "Documents", "Рабочий стол", "Документы")]
    for letter in string.ascii_uppercase[3:]:          # D:, E:, ... (C: — только папки пользователя)
        if os.path.exists(f"{letter}:\\"):
            roots.append(f"{letter}:\\")
    roots += list(extra)
    return [r for r in roots if os.path.isdir(r)]


def find(query, folders_only=False, kinds=None, limit=3, max_seconds=4.0, max_depth=5):
    """Ищет файлы/папки, похожие на сказанное название. Возвращает [(путь, оценка)]."""
    q = _norm_name(query)
    q_lat = q.translate(TRANSLIT)
    found = []
    deadline = time.time() + max_seconds
    for root in search_roots():
        base_depth = root.rstrip("\\/").count(os.sep)
        for dirpath, dirnames, filenames in os.walk(root):
            if time.time() > deadline:
                break
            dirnames[:] = [d for d in dirnames if d.lower() not in SKIP_DIRS and not d.startswith(".")]
            if dirpath.count(os.sep) - base_depth >= max_depth:
                dirnames[:] = []
            names = dirnames if folders_only else filenames
            for name in names:
                if kinds and not name.lower().endswith(kinds):
                    continue
                stem = _norm_name(os.path.splitext(name)[0] if not folders_only else name)
                if not stem:
                    continue
                if q == stem or q_lat == stem:
                    score = 1.0
                elif q in stem or q_lat in stem:
                    score = .85 + .1 * len(q) / max(len(stem), 1)
                else:
                    score = max(difflib.SequenceMatcher(None, q, stem).ratio(),
                                difflib.SequenceMatcher(None, q_lat, stem).ratio())
                if score >= .6:
                    found.append((os.path.join(dirpath, name), round(score, 3)))
    found.sort(key=lambda x: (-x[1], len(x[0])))
    seen, out = set(), []
    for p, s in found:
        if p not in seen:
            seen.add(p)
            out.append((p, s))
        if len(out) >= limit:
            break
    return out


def describe(path):
    """Как назвать найденное вслух: «отчёт.docx в папке Документы»."""
    name = os.path.basename(path)
    parent = os.path.basename(os.path.dirname(path)) or os.path.dirname(path)
    ru = {"Desktop": "на рабочем столе", "Documents": "в Документах", "Downloads": "в Загрузках",
          "Pictures": "в Изображениях", "Music": "в Музыке", "Videos": "в Видео"}
    where = ru.get(parent, f"в папке {parent}")
    return f"{name} {where}"


def is_risky(path):
    return path.lower().endswith(RISKY_EXT)


def open_path(path):
    os.startfile(path)
