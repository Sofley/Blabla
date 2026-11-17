"""«Мозг» Джарвиса: локальная модель через Ollama (бесплатно, без интернета)."""
import json
import os
import shutil
import subprocess
import time

import requests

PLAN_PROMPT = """Ты — Джарвис, голосовой помощник на компьютере с Windows. Хозяин управляет компьютером
только голосом: клавиатура у него не работает. Его речь распознана автоматически, без знаков препинания,
возможны ошибки распознавания — угадывай смысл.

Ответь СТРОГО одним JSON-объектом:
{"say": "что сказать вслух, коротко, по-русски", "actions": [{"name": "...", "args": {...}}]}

Доступные действия (можно несколько подряд или ни одного):
- open_app {"name": "название программы"}
- open_url {"url": "https://..."}
- web_search {"query": "запрос"}
- youtube {"query": "запрос"}
- type_text {"text": "текст для печати в активное окно"}
- hotkey {"keys": ["ctrl", "c"]}
- scroll {"direction": "up" или "down", "amount": 5}
- volume {"direction": "up" | "down" | "mute"}
- media {"key": "playpause" | "next" | "prev"}
- tg_send {"contact": "имя получателя как сказал хозяин", "text": "текст сообщения"}  (отправится только после подтверждения)
- tg_unread {}   — прочитать непрочитанные сообщения Telegram
- tg_call {"contact": "имя"}  — открыть чат для звонка в Telegram
- report {}  — отчёт о компьютере и сообщениях
- time {}
- lock {}

Если хозяин просто задаёт вопрос или хочет поговорить — дай ответ в "say" (2–4 предложения) и пустой actions.
Сообщение для tg_send пиши от первого лица хозяина, естественно, без кавычек.
"""

REPLY_PROMPT = """Ты помогаешь хозяину ответить в Telegram. Ниже последние сообщения переписки с «{name}».
Напиши ОДИН короткий естественный ответ от лица хозяина (1–2 предложения, по-русски, без кавычек и пояснений).
{hint}
Переписка:
{history}
Ответ:"""

SUMMARY_PROMPT = """Кратко перескажи по-русски для голосового озвучивания (не больше 5 предложений),
что пишут хозяину в Telegram, выдели важное и просьбы:
{text}"""


def find_ollama():
    exe = shutil.which("ollama")
    if exe:
        return exe
    p = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Ollama", "ollama.exe")
    return p if os.path.exists(p) else None


class Brain:
    def __init__(self, model="qwen2.5:7b", host="http://127.0.0.1:11434"):
        self.model = model
        self.host = host.rstrip("/")
        self.history = []

    def ensure_running(self, wait=30):
        if self._alive():
            return True
        exe = find_ollama()
        if not exe:
            return False
        flags = 0x08000000 if os.name == "nt" else 0  # CREATE_NO_WINDOW
        subprocess.Popen([exe, "serve"], creationflags=flags,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(wait):
            time.sleep(1)
            if self._alive():
                return True
        return False

    def _alive(self):
        try:
            return requests.get(self.host + "/api/tags", timeout=2).ok
        except requests.RequestException:
            return False

    def _chat(self, messages, json_mode=False, temperature=0.3):
        body = {"model": self.model, "messages": messages, "stream": False, "keep_alive": "60m",
                "options": {"temperature": temperature, "num_ctx": 4096}}
        if json_mode:
            body["format"] = "json"
        r = requests.post(self.host + "/api/chat", json=body, timeout=180)
        r.raise_for_status()
        return r.json()["message"]["content"].strip()

    def warm_up(self):
        try:
            self._chat([{"role": "user", "content": "ok"}])
        except Exception:
            pass

    def plan(self, command, context=""):
        msgs = [{"role": "system", "content": PLAN_PROMPT + ("\nКонтекст: " + context if context else "")}]
        msgs += self.history[-6:]
        msgs.append({"role": "user", "content": command})
        raw = self._chat(msgs, json_mode=True)
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            data = {"say": raw, "actions": []}
        if not isinstance(data, dict):
            data = {"say": str(data), "actions": []}
        data.setdefault("say", "")
        acts = data.get("actions") or []
        data["actions"] = [a for a in acts if isinstance(a, dict) and a.get("name")]
        self.history += [{"role": "user", "content": command},
                         {"role": "assistant", "content": json.dumps(data, ensure_ascii=False)}]
        self.history = self.history[-12:]
        return data

    def draft_reply(self, name, history_lines, hint=""):
        prompt = REPLY_PROMPT.format(name=name, history="\n".join(history_lines),
                                     hint=("Пожелание хозяина: " + hint) if hint else "")
        text = self._chat([{"role": "user", "content": prompt}], temperature=0.6)
        return text.strip().strip('"«»').split("\n")[0]

    def summarize(self, text):
        return self._chat([{"role": "user", "content": SUMMARY_PROMPT.format(text=text)}])
