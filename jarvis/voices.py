"""Голоса и фирменные фразы Джарвиса."""
import glob
import os
import random

# Готовые голоса. Microsoft Edge TTS: бесплатно, нужен интернет.
# «Multilingual»-голоса говорят по-русски с лёгким иностранным акцентом.
PRESETS = [
    {"name": "Джарвис классический", "engine": "edge", "voice": "ru-RU-DmitryNeural", "rate": "+5%", "pitch": "-8Hz"},
    {"name": "Француз", "engine": "edge", "voice": "fr-FR-RemyMultilingualNeural", "rate": "+0%", "pitch": "-4Hz"},
    {"name": "Бархатный", "engine": "edge", "voice": "en-US-AndrewMultilingualNeural", "rate": "+0%", "pitch": "-6Hz"},
    {"name": "Спокойный", "engine": "edge", "voice": "en-US-BrianMultilingualNeural", "rate": "-5%", "pitch": "-6Hz"},
    {"name": "Немецкий инженер", "engine": "edge", "voice": "de-DE-FlorianMultilingualNeural", "rate": "+0%", "pitch": "-4Hz"},
    {"name": "Низкий бас", "engine": "edge", "voice": "ru-RU-DmitryNeural", "rate": "-8%", "pitch": "-22Hz"},
    {"name": "Быстрый ассистент", "engine": "edge", "voice": "ru-RU-DmitryNeural", "rate": "+25%", "pitch": "+0Hz"},
    {"name": "Светлана", "engine": "edge", "voice": "ru-RU-SvetlanaNeural", "rate": "+5%", "pitch": "+0Hz"},
    {"name": "Ава", "engine": "edge", "voice": "en-US-AvaMultilingualNeural", "rate": "+0%", "pitch": "+0Hz"},
    {"name": "Эмма", "engine": "edge", "voice": "en-US-EmmaMultilingualNeural", "rate": "+0%", "pitch": "+0Hz"},
    {"name": "Итальянец", "engine": "edge", "voice": "it-IT-GiuseppeMultilingualNeural", "rate": "+0%", "pitch": "-6Hz"},
    {"name": "Весёлый", "engine": "edge", "voice": "ru-RU-DmitryNeural", "rate": "+14%", "pitch": "+14Hz"},
    {"name": "Голос Windows", "engine": "sapi", "note": "без интернета"},
    {"name": "Мой голос из ElevenLabs", "engine": "elevenlabs", "note": "нужны ключ и voice_id в config.json"},
]

SAMPLE = "Добрый день{a}. Я Джарвис. Все системы работают в штатном режиме."

# Фирменные фразы. {a} -> ", сэр" (обращение из настроек).
PHRASES = {
    "greeting": ["К вашим услугам{a}.", "Джарвис на связи. Все системы в норме{a}.",
                 "С возвращением{a}. Чем могу помочь?"],
    "listening": ["Да{a}?", "Слушаю{a}.", "Я весь внимание{a}."],
    "opening": ["Открываю{a}.", "Сию минуту.", "Уже открываю."],
    "searching": ["Ищу{a}.", "Запускаю поиск.", "Сейчас найду."],
    "youtube": ["Ищу на ютубе{a}.", "Открываю ютуб."],
    "sent": ["Отправлено{a}.", "Сообщение доставлено.", "Готово, отправил."],
    "cancelled": ["Отменено{a}.", "Как скажете, отменил."],
    "thinking": ["Секунду{a}.", "Анализирую.", "Одну минуту."],
    "stop": ["Обращайтесь{a}.", "Всегда к вашим услугам.", "Буду рядом{a}."],
    "bye": ["Отключаюсь. До встречи{a}."],
    "done": ["Готово{a}.", "Выполнено."],
    "dictation_on": ["Диктуйте{a}. Знаки препинания говорите словами. Закончить — «стоп диктовка»."],
    "dictation_off": ["Диктовка закончена{a}."],
    "no_messages": ["Новых сообщений нет{a}.", "В телеграме тихо{a}."],
    "confirm": ["Отправить?", "Отправляем{a}?"],
    "error": ["Боюсь, не получилось{a}."],
    "not_understood": ["Простите{a}, не понял команду."],
}


def address_suffix(address):
    address = (address or "").strip()
    return f", {address}" if address else ""


def phrase(key, address="сэр"):
    return random.choice(PHRASES[key]).format(a=address_suffix(address))


def custom_phrase_file(folder, key):
    """Ваши записи: voices/custom/listening.mp3, listening_2.wav и т.п. — выбирается случайная."""
    if not folder or not os.path.isdir(folder):
        return None
    files = []
    for ext in ("mp3", "wav"):
        files += glob.glob(os.path.join(folder, f"{key}.{ext}"))
        files += glob.glob(os.path.join(folder, f"{key}_*.{ext}"))
    return random.choice(files) if files else None


NUM_WORDS = {"один": 1, "первый": 1, "два": 2, "второй": 2, "три": 3, "третий": 3, "четыре": 4, "четвертый": 4,
             "пять": 5, "пятый": 5, "шесть": 6, "шестой": 6, "семь": 7, "седьмой": 7, "восемь": 8, "восьмой": 8,
             "девять": 9, "девятый": 9, "десять": 10, "десятый": 10, "одиннадцать": 11, "одиннадцатый": 11,
             "двенадцать": 12, "двенадцатый": 12}


def parse_number(text):
    for w in text.split():
        if w.isdigit():
            return int(w)
        if w in NUM_WORDS:
            return NUM_WORDS[w]
    return None
