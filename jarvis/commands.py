"""Разбор распознанной речи в команды (без зависимостей, тестируется на любой ОС)."""
import difflib
import re

YES = {"да", "давай", "отправь", "отправляй", "подтверждаю", "верно", "конечно", "ага", "угу",
       "да отправь", "да отправляй", "отправить", "можно", "согласен", "выполняй", "делай"}
NO = {"нет", "отмена", "отмени", "не надо", "не отправляй", "стоп", "не", "нет не надо"}

# Сайты, которые открываются по названию
SITES = {
    "ютуб": "https://www.youtube.com",
    "youtube": "https://www.youtube.com",
    "гугл": "https://www.google.com",
    "google": "https://www.google.com",
    "яндекс": "https://ya.ru",
    "вконтакте": "https://vk.com",
    "вк": "https://vk.com",
    "почту": "https://mail.google.com",
    "почта": "https://mail.google.com",
    "гугл почту": "https://mail.google.com",
    "яндекс почту": "https://mail.yandex.ru",
    "переводчик": "https://translate.google.com",
    "карты": "https://yandex.ru/maps",
    "погоду": "https://yandex.ru/pogoda",
    "погода": "https://yandex.ru/pogoda",
    "чат": "https://claude.ai",
    "клод": "https://claude.ai",
    "инстаграм": "https://www.instagram.com",
    "википедию": "https://ru.wikipedia.org",
    "кинопоиск": "https://www.kinopoisk.ru",
    "авито": "https://www.avito.ru",
    "озон": "https://www.ozon.ru",
    "вайлдберриз": "https://www.wildberries.ru",
    "ватсап": "https://web.whatsapp.com",
}

# Голосовые фразы -> сочетания клавиш
HOTKEYS = {
    "энтер": ["enter"], "ввод": ["enter"], "enter": ["enter"], "интер": ["enter"],
    "пробел": ["space"],
    "удали": ["backspace"], "стереть": ["backspace"], "сотри": ["backspace"], "бэкспейс": ["backspace"],
    "удали слово": ["ctrl", "backspace"], "сотри слово": ["ctrl", "backspace"],
    "таб": ["tab"], "табуляция": ["tab"],
    "эскейп": ["esc"], "escape": ["esc"], "искейп": ["esc"],
    "стрелка вверх": ["up"], "стрелка вниз": ["down"], "стрелка влево": ["left"], "стрелка вправо": ["right"],
    "копировать": ["ctrl", "c"], "скопируй": ["ctrl", "c"], "копируй": ["ctrl", "c"],
    "вставь": ["ctrl", "v"], "вставить": ["ctrl", "v"],
    "вырежи": ["ctrl", "x"], "вырезать": ["ctrl", "x"],
    "выдели все": ["ctrl", "a"], "выделить все": ["ctrl", "a"],
    "отмени": ["ctrl", "z"], "отменить": ["ctrl", "z"], "верни": ["ctrl", "y"],
    "сохрани": ["ctrl", "s"], "сохранить": ["ctrl", "s"],
    "новая вкладка": ["ctrl", "t"], "открой новую вкладку": ["ctrl", "t"],
    "закрой вкладку": ["ctrl", "w"], "закрыть вкладку": ["ctrl", "w"],
    "следующая вкладка": ["ctrl", "tab"], "предыдущая вкладка": ["ctrl", "shift", "tab"],
    "обнови": ["f5"], "обнови страницу": ["f5"], "обновить": ["f5"],
    "назад": ["alt", "left"], "вперед": ["alt", "right"],
    "закрой окно": ["alt", "f4"], "закрой программу": ["alt", "f4"], "закрой это": ["alt", "f4"],
    "переключи окно": ["alt", "tab"], "другое окно": ["alt", "tab"], "следующее окно": ["alt", "tab"],
    "сверни все": ["win", "d"], "рабочий стол": ["win", "d"], "покажи рабочий стол": ["win", "d"],
    "сверни окно": ["win", "down"], "сверни": ["win", "down"],
    "разверни окно": ["win", "up"], "разверни": ["win", "up"],
    "пуск": ["win"], "открой пуск": ["win"],
    "найди на странице": ["ctrl", "f"],
    "крупнее": ["ctrl", "+"], "увеличь": ["ctrl", "+"], "мельче": ["ctrl", "-"], "уменьши": ["ctrl", "-"],
    "полный экран": ["f11"], "на весь экран": ["f11"],
    "адресная строка": ["ctrl", "l"],
}

SCROLL = {
    "листай вниз": ("down", 5), "прокрути вниз": ("down", 5), "ниже": ("down", 3), "вниз": ("down", 5),
    "листай вверх": ("up", 5), "прокрути вверх": ("up", 5), "выше": ("up", 3), "вверх": ("up", 5),
    "в самый низ": ("bottom", 0), "в конец": ("bottom", 0), "в начало": ("top", 0), "в самый верх": ("top", 0),
}

NUMBERS = {"один", "первый", "два", "второй", "три", "третий", "четыре", "четвертый", "пять", "пятый",
           "шесть", "шестой", "семь", "седьмой", "восемь", "восьмой", "девять", "девятый", "десять",
           "десятый", "одиннадцать", "одиннадцатый", "двенадцать", "двенадцатый"}

STOP_WORDS = {"спасибо", "отбой", "все спасибо", "пока", "хватит", "свободен"}
EXIT_WORDS = {"выключись", "завершить работу джарвиса", "выход", "закройся"}


def norm(text):
    text = (text or "").lower().replace("ё", "е")
    text = re.sub(r"[^\w\s+-]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def strip_wake(text, wake_words, threshold=0.75):
    """Ищет слово-обращение в начале фразы. Возвращает (нашли ли, остаток фразы)."""
    words = text.split()
    for start in range(min(3, len(words))):
        for n in (1, 2):
            if start + n > len(words):
                continue
            cand = "".join(words[start:start + n])
            for w in wake_words:
                if difflib.SequenceMatcher(None, cand, w).ratio() >= threshold:
                    return True, " ".join(words[start + n:])
    return False, text


def is_yes(text):
    t = norm(text)
    return t in YES or t.split()[:1] in (["да"], ["отправь"], ["отправляй"])


def is_no(text):
    t = norm(text)
    return t in NO or t.startswith("нет") or t.startswith("не надо") or t.startswith("отмен")


def _after(text, prefixes):
    for p in prefixes:
        if text == p:
            return ""
        if text.startswith(p + " "):
            return text[len(p) + 1:].strip()
    return None


def parse(text):
    """Быстрые правила. Возвращает dict с полем intent или None (тогда думает ИИ)."""
    t = norm(text)
    t = re.sub(r"\b(пожалуйста|будь добр|быстренько)\b", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    t = re.sub(r"^(а |ну |слушай |так )", "", t)
    t = re.sub(r"^(открой|запусти|включи|найди|покажи) мне ", r"\1 ", t)
    if not t:
        return None

    if t in STOP_WORDS:
        return {"intent": "stop"}
    if t in EXIT_WORDS:
        return {"intent": "exit"}
    if t in {"помощь", "что ты умеешь", "команды", "какие есть команды"}:
        return {"intent": "help"}

    # --- Голос и внешний вид Джарвиса
    if t in {"смени голос", "другой голос", "следующий голос", "поменяй голос"}:
        return {"intent": "voice_next"}
    if t in {"какие есть голоса", "список голосов", "назови голоса"}:
        return {"intent": "voice_list"}
    if t in {"прослушать голоса", "покажи голоса", "послушать голоса", "проиграй голоса", "образцы голосов"}:
        return {"intent": "voice_demo"}
    rest = _after(t, ["голос номер", "включи голос номер", "выбери голос номер", "голос"])
    if rest and any(ch.isdigit() for ch in rest) or (rest and rest.split()[0] in NUMBERS):
        return {"intent": "voice_set", "number": rest}
    rest = _after(t, ["цвет", "смени цвет на", "сделай цвет", "поменяй цвет на"])
    if rest:
        return {"intent": "theme", "name": rest}
    if t in {"спрячься", "скройся", "убери окно", "спрячь окно"}:
        return {"intent": "hide"}
    if t in {"покажись", "покажи себя", "появись", "покажи окно"}:
        return {"intent": "show"}

    # --- Диктовка
    if t in {"диктовка", "начни диктовку", "режим диктовки", "буду диктовать", "печатай за мной"}:
        return {"intent": "dictation_on"}
    rest = _after(t, ["напечатай", "печатай", "введи", "набери"])
    if rest:
        return {"intent": "type", "text": rest}

    # --- Время и система
    if t in {"который час", "сколько времени", "время", "сколько сейчас времени"}:
        return {"intent": "time"}
    if t in {"какое сегодня число", "какая сегодня дата", "дата", "какой сегодня день"}:
        return {"intent": "date"}
    if t in {"отчет", "доклад", "доложи", "отчитайся", "статус", "дай отчет", "что нового"}:
        return {"intent": "report"}
    if t in {"заблокируй компьютер", "заблокируй", "блокировка"}:
        return {"intent": "lock"}
    if t in {"выключи компьютер", "выключение компьютера", "выключи пк"}:
        return {"intent": "shutdown"}
    if t in {"перезагрузи компьютер", "перезагрузка", "перезагрузи"}:
        return {"intent": "restart"}
    if t in {"спящий режим", "усни", "режим сна"}:
        return {"intent": "sleep"}
    if t in {"скриншот", "сделай скриншот", "снимок экрана"}:
        return {"intent": "screenshot"}

    # --- Звук и медиа
    if t in {"громче", "сделай громче", "прибавь звук", "погромче"}:
        return {"intent": "volume", "direction": "up"}
    if t in {"тише", "сделай тише", "убавь звук", "потише"}:
        return {"intent": "volume", "direction": "down"}
    if t in {"выключи звук", "без звука", "включи звук", "звук"}:
        return {"intent": "volume", "direction": "mute"}
    if t in {"пауза", "стоп музыка", "продолжи", "играй", "воспроизведение"}:
        return {"intent": "media", "key": "playpause"}
    if t in {"следующий трек", "следующая песня", "дальше"}:
        return {"intent": "media", "key": "next"}
    if t in {"предыдущий трек", "предыдущая песня"}:
        return {"intent": "media", "key": "prev"}

    # --- Мышь
    if t in {"клик", "кликни", "нажми мышкой", "щелкни"}:
        return {"intent": "click", "button": "left", "double": False}
    if t in {"двойной клик", "дважды кликни"}:
        return {"intent": "click", "button": "left", "double": True}
    if t in {"правый клик", "правой кнопкой", "контекстное меню"}:
        return {"intent": "click", "button": "right", "double": False}

    # --- Прокрутка и клавиши
    if t in SCROLL:
        d, n = SCROLL[t]
        return {"intent": "scroll", "direction": d, "amount": n}
    key_phrase = _after(t, ["нажми", "нажать", "клавиша"])
    if key_phrase is not None and key_phrase in HOTKEYS:
        return {"intent": "hotkey", "keys": HOTKEYS[key_phrase]}
    if t in HOTKEYS:
        return {"intent": "hotkey", "keys": HOTKEYS[t]}

    # --- Telegram
    if t in {"сообщения", "непрочитанные", "прочитай сообщения", "что в телеграме", "что нового в телеграме",
             "проверь сообщения", "есть сообщения", "новые сообщения", "прочитай непрочитанные"}:
        return {"intent": "tg_unread"}
    if t in {"придумай ответ", "предложи ответ", "ответь сам", "придумай что ответить"}:
        return {"intent": "tg_draft"}
    rest = _after(t, ["ответь", "ответить", "ответь ему", "ответь ей", "ответь им"])
    if rest is not None:
        return {"intent": "tg_reply", "text": rest}
    rest = _after(t, ["позвони", "набери в телеграме", "звонок", "позвонить"])
    if rest:
        return {"intent": "tg_call", "contact": rest}
    rest = _after(t, ["открой чат с", "открой чат", "открой переписку с"])
    if rest:
        return {"intent": "tg_open", "contact": rest}

    # --- Поиск
    rest = _after(t, ["найди на ютубе", "включи на ютубе", "ютуб", "поищи на ютубе", "найди видео", "включи видео"])
    if rest:
        return {"intent": "youtube", "query": rest}
    rest = _after(t, ["найди в интернете", "найди", "поищи", "загугли", "поиск"])
    if rest:
        return {"intent": "search", "query": rest}

    # --- Открыть
    rest = _after(t, ["открой", "запусти", "включи", "открыть", "запустить"])
    if rest:
        if rest in SITES:
            return {"intent": "url", "url": SITES[rest]}
        if rest.startswith("сайт "):
            return None  # адрес сайта лучше угадает ИИ
        return {"intent": "open", "name": rest}

    return None



PUNCT = [
    (r"\s*\bвопросительный знак\b", "?"),
    (r"\s*\bвосклицательный знак\b", "!"),
    (r"\s*\bточка с запятой\b", ";"),
    (r"\s*\bточка\b", "."),
    (r"\s*\bзапятая\b", ","),
    (r"\s*\bдвоеточие\b", ":"),
    (r"\s*\bтире\b", " —"),
    (r"\s*\b(новая строка|с новой строки|абзац)\b\s*", "\n"),
    (r"\bоткрыть скобку\s*", "("),
    (r"\s*\bзакрыть скобку\b", ")"),
    (r"\bкавычки\b", "\""),
]


def dictation_text(spoken, capitalize_first):
    """Превращает «привет запятая как дела вопросительный знак» в «Привет, как дела?»."""
    s = spoken
    for pat, rep in PUNCT:
        s = re.sub(pat, rep, s)
    out = []
    cap = capitalize_first
    for ch in s:
        if cap and ch.isalpha():
            out.append(ch.upper())
            cap = False
        else:
            out.append(ch)
        if ch in ".!?\n":
            cap = True
    res = "".join(out)
    if not res.endswith("\n"):
        res += " "
    return res, res.rstrip(" ").endswith((".", "!", "?", "\n"))


HELP = (
    "Я умею: открывать программы и сайты — «открой хром», «открой ютуб». "
    "Искать — «найди рецепт борща», «найди на ютубе музыку». "
    "Печатать — «напечатай привет» или режим «диктовка», выход — «стоп диктовка». "
    "Клавиши — «нажми энтер», «скопируй», «вставь», «закрой вкладку», «листай вниз». "
    "Звук — «громче», «тише», «пауза». "
    "Телеграм — «сообщения», «ответь …», «придумай ответ», «напиши маме что я скоро буду», «позвони маме». "
    "Голос — «смени голос», «прослушать голоса», «голос номер три». Цвет — «цвет золотой». "
    "Окно — «спрячься», «покажись». "
    "Отчёт — «отчёт». На любой другой вопрос отвечу с помощью ИИ. Закончить разговор — «спасибо»."
)
