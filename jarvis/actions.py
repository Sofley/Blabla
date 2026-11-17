"""Управление компьютером Windows: программы, сайты, клавиши, мышь, звук."""
import datetime
import os
import subprocess
import time
import urllib.parse
import webbrowser

import pyautogui
import pyperclip

pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0.05

LOCAL = os.environ.get("LOCALAPPDATA", "")
APPDATA = os.environ.get("APPDATA", "")
PF = os.environ.get("ProgramFiles", r"C:\Program Files")
PF86 = os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")

# Голосовое название -> команда/путь. Если путь не найден — ищем через меню «Пуск».
APPS = {
    "браузер": "browser",
    "хром": [os.path.join(PF, r"Google\Chrome\Application\chrome.exe"),
             os.path.join(PF86, r"Google\Chrome\Application\chrome.exe"),
             os.path.join(LOCAL, r"Google\Chrome\Application\chrome.exe")],
    "гугл хром": "хром",
    "edge": ["msedge"], "эдж": ["msedge"], "майкрософт эдж": ["msedge"],
    "яндекс браузер": [os.path.join(LOCAL, r"Yandex\YandexBrowser\Application\browser.exe")],
    "телеграм": [os.path.join(APPDATA, r"Telegram Desktop\Telegram.exe"), "tg://"],
    "телеграмм": "телеграм",
    "блокнот": ["notepad"],
    "калькулятор": ["calc"],
    "проводник": ["explorer"], "папки": ["explorer"], "мой компьютер": ["explorer"],
    "загрузки": ["explorer", os.path.join(os.path.expanduser("~"), "Downloads")],
    "документы": ["explorer", os.path.join(os.path.expanduser("~"), "Documents")],
    "настройки": ["ms-settings:"], "параметры": ["ms-settings:"],
    "диспетчер задач": ["taskmgr"],
    "паинт": ["mspaint"], "пэйнт": ["mspaint"],
    "ворд": ["winword"], "word": ["winword"],
    "эксель": ["excel"], "excel": ["excel"],
    "повер поинт": ["powerpnt"], "презентации": ["powerpnt"],
    "командную строку": ["cmd"], "командная строка": ["cmd"],
    "экранную клавиатуру": ["osk"], "экранная клавиатура": ["osk"],
    "камеру": ["microsoft.windows.camera:"], "камера": ["microsoft.windows.camera:"],
    "музыку": ["mswindowsmusic:"],
    "фото": ["ms-photos:"],
    "часы": ["ms-clock:"], "будильник": ["ms-clock:"],
    "магазин": ["ms-windows-store:"],
    "спотифай": [os.path.join(APPDATA, r"Spotify\Spotify.exe"), "spotify:"],
    "дискорд": [os.path.join(LOCAL, r"Discord\Update.exe")],
    "ватсап": ["whatsapp:"], "вотсап": ["whatsapp:"],
    "зум": ["zoommtg:"],
    "стим": ["steam:"],
}


def _launch(target, *args):
    if target == "browser":
        webbrowser.open("https://www.google.com")
        return True
    if target.endswith(":") or target.startswith(("tg://", "ms-", "http")):
        os.startfile(target)
        return True
    if os.path.isabs(target):
        if not os.path.exists(target):
            return False
        if target.lower().endswith("update.exe"):  # Discord
            subprocess.Popen([target, "--processStart", "Discord.exe"])
        else:
            subprocess.Popen([target, *args])
        return True
    subprocess.Popen(["cmd", "/c", "start", "", target, *args], creationflags=0x08000000)
    return True


def open_app(name):
    name = name.strip().lower()
    spec = APPS.get(name)
    if isinstance(spec, str) and spec in APPS:
        spec = APPS[spec]
    if spec == "browser":
        return _launch("browser")
    if spec:
        if spec[0] == "explorer":
            subprocess.Popen(["explorer", *spec[1:]])
            return True
        for target in spec:
            try:
                if _launch(target):
                    return True
            except OSError:
                continue
    return start_menu_search(name)


def start_menu_search(text):
    """Открывает «Пуск», вставляет название программы и нажимает Enter."""
    pyautogui.press("win")
    time.sleep(0.9)
    paste(text)
    time.sleep(1.5)
    pyautogui.press("enter")
    return True


def open_url(url):
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    webbrowser.open(url)


def web_search(query, engine="google"):
    q = urllib.parse.quote_plus(query)
    url = (f"https://yandex.ru/search/?text={q}" if engine == "yandex"
           else f"https://www.google.com/search?q={q}")
    webbrowser.open(url)


def youtube(query):
    webbrowser.open("https://www.youtube.com/results?search_query=" + urllib.parse.quote_plus(query))


def paste(text):
    """Печатает любой текст (в т.ч. русский) через буфер обмена."""
    try:
        old = pyperclip.paste()
    except Exception:
        old = None
    pyperclip.copy(text)
    time.sleep(0.05)
    pyautogui.hotkey("ctrl", "v")
    time.sleep(0.15)
    if old is not None:
        try:
            pyperclip.copy(old)
        except Exception:
            pass


def type_text(text):
    if text.endswith("\n"):
        paste(text.rstrip("\n"))
        pyautogui.press("enter")
    elif "\n" in text:
        parts = text.split("\n")
        for i, p in enumerate(parts):
            if p:
                paste(p)
            if i < len(parts) - 1:
                pyautogui.hotkey("shift", "enter")
    else:
        paste(text)


def hotkey(keys):
    keys = [k.lower() for k in keys]
    if len(keys) == 1:
        pyautogui.press(keys[0])
    else:
        pyautogui.hotkey(*keys)


def scroll(direction, amount=5):
    if direction == "bottom":
        pyautogui.press("end")
    elif direction == "top":
        pyautogui.press("home")
    else:
        pyautogui.scroll((1 if direction == "up" else -1) * 120 * int(amount or 5))


def volume(direction):
    key = {"up": "volumeup", "down": "volumedown", "mute": "volumemute"}[direction]
    pyautogui.press(key, presses=1 if key == "volumemute" else 5)


def media(key):
    pyautogui.press({"playpause": "playpause", "next": "nexttrack", "prev": "prevtrack"}[key])


def click(button="left", double=False):
    if double:
        pyautogui.doubleClick(button=button)
    else:
        pyautogui.click(button=button)


def screenshot():
    folder = os.path.join(os.path.expanduser("~"), "Pictures", "Jarvis")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, datetime.datetime.now().strftime("screen_%Y-%m-%d_%H-%M-%S.png"))
    pyautogui.screenshot(path)
    return path


def lock():
    subprocess.Popen(["rundll32.exe", "user32.dll,LockWorkStation"])


def shutdown():
    subprocess.Popen(["shutdown", "/s", "/t", "15"])


def restart():
    subprocess.Popen(["shutdown", "/r", "/t", "15"])


def sleep_pc():
    subprocess.Popen(["rundll32.exe", "powrprof.dll,SetSuspendState", "0,1,0"])


MONTHS = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа",
          "сентября", "октября", "ноября", "декабря"]
DAYS = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]


def time_text():
    n = datetime.datetime.now()
    return f"Сейчас {n.hour}:{n.minute:02d}"


def date_text():
    n = datetime.datetime.now()
    return f"Сегодня {DAYS[n.weekday()]}, {n.day} {MONTHS[n.month - 1]} {n.year} года"


def system_status():
    import psutil
    parts = [time_text() + "."]
    parts.append(f"Процессор загружен на {int(psutil.cpu_percent(interval=0.5))} процентов, "
                 f"память — на {int(psutil.virtual_memory().percent)} процентов.")
    b = psutil.sensors_battery()
    if b:
        parts.append(f"Батарея {int(b.percent)} процентов" + (", на зарядке." if b.power_plugged else "."))
    disk = psutil.disk_usage(os.environ.get("SystemDrive", "C:") + "\\")
    parts.append(f"На диске свободно {disk.free // (1024 ** 3)} гигабайт.")
    return " ".join(parts)
