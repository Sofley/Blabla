"""Джарвис — голосовое управление компьютером на Windows.

Запуск: start_jarvis.bat (или python jarvis.py из этой папки).
"""
import json
import os
import queue
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import actions  # noqa: E402
import commands as C  # noqa: E402
from brain import Brain  # noqa: E402
from voice import Listener, Speaker  # noqa: E402

CONFIG_PATH = os.path.join(HERE, "config.json")


def load_config():
    with open(os.path.join(HERE, "config.example.json"), encoding="utf-8") as f:
        cfg = json.load(f)
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as f:
            cfg.update(json.load(f))
    return cfg


class Jarvis:
    def __init__(self, cfg):
        self.cfg = cfg
        model_dir = os.path.join(HERE, cfg["vosk_model"])
        if not os.path.isdir(model_dir):
            raise SystemExit("Нет модели распознавания речи. Запустите install.bat")
        self.ear = Listener(model_dir, device=cfg.get("microphone"))
        self.voice = Speaker(self.ear, voice=cfg["voice"], rate=cfg.get("voice_rate", "+10%"),
                             use_online=cfg.get("online_voice", True))
        self.brain = Brain(cfg["llm_model"], cfg.get("ollama_host", "http://127.0.0.1:11434"))
        self.wake = [C.norm(w) for w in cfg["wake_words"]]
        self.follow_up = float(cfg.get("follow_up_seconds", 12))
        self.active_until = 0.0
        self.pending = None
        self.dictation = False
        self.dict_cap = True
        self.last_chat = None  # {"chat_id", "name"}
        self.notifications = queue.Queue()
        self.tg = None
        self.brain_ok = False

    # ------------------------------------------------------------------ helpers
    def say(self, text):
        self.voice.say(text)

    def keep_listening(self):
        self.active_until = time.time() + self.follow_up

    def start_services(self):
        self.brain_ok = self.brain.ensure_running()
        if self.brain_ok:
            print("ИИ (Ollama) запущен, модель:", self.brain.model)
            self.brain.warm_up()
        else:
            print("ВНИМАНИЕ: Ollama не запущена — сложные вопросы недоступны, простые команды работают.")

        tg = self.cfg.get("telegram") or {}
        if tg.get("api_id") and tg.get("api_hash"):
            try:
                from telegram_agent import TelegramAgent
                self.tg = TelegramAgent(tg["api_id"], tg["api_hash"], os.path.join(HERE, "telegram"),
                                        self.notifications.put, tg.get("announce_groups", False))
                me = self.tg.start()
                print("Telegram подключён:", me)
            except Exception as e:
                print("Telegram не подключился:", e)
                self.tg = None

    # ------------------------------------------------------------------ main loop
    def run(self):
        self.start_services()
        names = " или ".join(f"«{w.capitalize()}»" for w in self.cfg["wake_words"][:2])
        self.say(f"Джарвис на связи. Обращайтесь ко мне {names}.")
        report_every = float(self.cfg.get("report_every_minutes", 0)) * 60
        next_report = time.time() + report_every if report_every else None

        while True:
            self.announce_notifications()
            if next_report and time.time() >= next_report:
                next_report = time.time() + report_every
                self.periodic_report()

            text = self.ear.listen(timeout=1.0)
            if not text:
                continue
            text = C.norm(text)
            print(f"Вы: {text}", flush=True)

            try:
                if self.dictation:
                    self.handle_dictation(text)
                    continue

                woke, rest = C.strip_wake(text, self.wake)
                if self.pending:
                    self.handle_pending(rest if woke else text)
                    continue
                if not woke and time.time() > self.active_until:
                    continue  # фраза не нам
                if woke and not rest:
                    self.say("Слушаю.")
                    self.keep_listening()
                    continue

                keep = self.handle(rest if woke else text)
                if keep is False:
                    self.active_until = 0
                else:
                    self.keep_listening()
            except SystemExit:
                raise
            except Exception as e:
                traceback.print_exc()
                self.say(f"Не получилось: {e}")

    # ------------------------------------------------------------------ dictation
    def handle_dictation(self, text):
        _, rest = C.strip_wake(text, self.wake)
        if rest in {"стоп диктовка", "стоп", "закончить диктовку", "конец диктовки", "хватит"} or \
                text in {"стоп диктовка", "конец диктовки", "закончить диктовку"}:
            self.dictation = False
            self.say("Диктовка закончена.")
            self.keep_listening()
            return
        cmd = C.parse(rest) if rest != text else None  # «Джарвис нажми энтер» во время диктовки
        if cmd and cmd["intent"] in {"hotkey", "scroll", "click"}:
            self.execute_intent(cmd)
            return
        typed, self.dict_cap = C.dictation_text(text, self.dict_cap)
        actions.type_text(typed)

    # ------------------------------------------------------------------ confirmations
    def handle_pending(self, text):
        p = self.pending
        if p["type"] == "reply_text":
            self.pending = None
            if C.is_no(text):
                self.say("Хорошо, не отвечаю.")
            elif text in {"придумай", "придумай сам", "придумай ответ", "сам"}:
                self.draft_reply(p["chat"])
            else:
                self.confirm_send(p["chat"], text)
            return
        if C.is_yes(text):
            self.pending = None
            if p["type"] == "send":
                self.tg.send(p["chat"]["chat_id"], p["text"])
                self.last_chat = p["chat"]
                self.say("Отправил.")
            elif p["type"] == "shutdown":
                self.say("Выключаю компьютер.")
                actions.shutdown()
            elif p["type"] == "restart":
                self.say("Перезагружаю.")
                actions.restart()
            self.keep_listening()
        elif C.is_no(text):
            self.pending = None
            self.say("Отменил.")
            self.keep_listening()
        elif p["type"] == "send":
            fix = None
            for pref in ("измени на", "исправь на", "замени на", "напиши лучше", "лучше"):
                if text.startswith(pref + " "):
                    fix = text[len(pref) + 1:]
            if fix:
                p["text"] = fix[:1].upper() + fix[1:]
                self.say(f"Исправил: {p['text']}. Отправить?")
            elif text in {"придумай другой", "другой вариант", "по другому"}:
                self.pending = None
                self.draft_reply(p["chat"])
            else:
                self.say("Скажите «да», чтобы отправить, «нет» — чтобы отменить, или «измени на» и новый текст.")
        else:
            self.say("Скажите «да» или «нет».")

    # ------------------------------------------------------------------ commands
    def handle(self, text):
        cmd = C.parse(text)
        if cmd:
            return self.execute_intent(cmd)
        return self.ask_brain(text)

    def execute_intent(self, cmd):
        i = cmd["intent"]
        if i == "stop":
            self.say("Обращайтесь.")
            return False
        if i == "exit":
            self.say("Отключаюсь. До встречи.")
            raise SystemExit(0)
        if i == "help":
            self.say(C.HELP)
        elif i == "dictation_on":
            self.dictation = True
            self.dict_cap = True
            self.say("Диктуйте. Знаки препинания говорите словами. Чтобы закончить, скажите «стоп диктовка».")
        elif i == "type":
            actions.type_text(cmd["text"])
        elif i == "time":
            self.say(actions.time_text())
        elif i == "date":
            self.say(actions.date_text())
        elif i == "report":
            self.report()
        elif i == "lock":
            self.say("Блокирую.")
            actions.lock()
            return False
        elif i in ("shutdown", "restart"):
            self.pending = {"type": i}
            self.say("Точно выключить компьютер?" if i == "shutdown" else "Точно перезагрузить компьютер?")
        elif i == "sleep":
            self.say("Перевожу в сон.")
            actions.sleep_pc()
            return False
        elif i == "screenshot":
            path = actions.screenshot()
            self.say("Скриншот сохранён в папку Изображения, Jarvis.")
            print(path)
        elif i == "volume":
            actions.volume(cmd["direction"])
        elif i == "media":
            actions.media(cmd["key"])
        elif i == "click":
            actions.click(cmd["button"], cmd["double"])
        elif i == "scroll":
            actions.scroll(cmd["direction"], cmd["amount"])
        elif i == "hotkey":
            actions.hotkey(cmd["keys"])
        elif i == "url":
            actions.open_url(cmd["url"])
            self.say("Открываю.")
        elif i == "open":
            actions.open_app(cmd["name"])
            self.say(f"Открываю {cmd['name']}.")
        elif i == "search":
            actions.web_search(cmd["query"], self.cfg.get("search_engine", "google"))
            self.say("Ищу.")
        elif i == "youtube":
            actions.youtube(cmd["query"])
            self.say("Ищу на ютубе.")
        elif i.startswith("tg_"):
            return self.telegram_intent(cmd)
        return True

    # ------------------------------------------------------------------ telegram
    def need_tg(self):
        if not self.tg:
            self.say("Телеграм не подключён. Запустите файл setup_telegram в папке Джарвиса.")
            return False
        return True

    def telegram_intent(self, cmd):
        if not self.need_tg():
            return True
        i = cmd["intent"]
        if i == "tg_unread":
            self.read_unread()
        elif i == "tg_draft":
            if self.last_chat:
                self.draft_reply(self.last_chat)
            else:
                self.say("Не знаю, кому отвечать. Скажите «сообщения», чтобы я их прочитал.")
        elif i == "tg_reply":
            if not self.last_chat:
                self.say("Не знаю, кому отвечать. Скажите, например: напиши маме, что я скоро буду.")
            elif cmd["text"]:
                self.confirm_send(self.last_chat, cmd["text"])
            else:
                self.pending = {"type": "reply_text", "chat": self.last_chat}
                self.say(f"Что ответить {self.last_chat['name']}? Или скажите «придумай».")
        elif i == "tg_send":
            chat = self.tg.find_chat(cmd["contact"])
            if not chat:
                self.say(f"Не нашёл в телеграме контакт «{cmd['contact']}».")
            else:
                self.confirm_send(chat, cmd["text"])
        elif i in ("tg_call", "tg_open"):
            chat = self.tg.find_chat(cmd["contact"])
            if not chat:
                self.say(f"Не нашёл в телеграме контакт «{cmd['contact']}».")
            else:
                self.last_chat = chat
                opened = self.tg.open_chat_in_app(chat)
                if i == "tg_call":
                    self.say(f"Открыл чат с {chat['name']}. Нажмите мышкой на значок трубки вверху справа."
                             if opened else "Открыл телеграм, найдите чат мышкой.")
                else:
                    self.say(f"Открыл чат с {chat['name']}.")
        return True

    def confirm_send(self, chat, text):
        text = text.strip()
        if not text:
            return
        text = text[:1].upper() + text[1:]
        self.pending = {"type": "send", "chat": chat, "text": text}
        self.say(f"Сообщение для «{chat['name']}»: {text}. Отправить?")

    def draft_reply(self, chat, hint=""):
        if not self.brain_ok:
            self.say("ИИ не запущен, скажите текст ответа сами.")
            self.pending = {"type": "reply_text", "chat": chat}
            return
        self.say("Секунду, придумываю.")
        hist = self.tg.history(chat["chat_id"])
        text = self.brain.draft_reply(chat["name"], hist, hint)
        self.confirm_send(chat, text)

    def read_unread(self):
        chats = self.tg.unread()
        if not chats:
            self.say("Новых сообщений нет.")
            return
        total = sum(c["count"] for c in chats)
        parts = [f"Непрочитанных чатов: {len(chats)}, сообщений: {total}."]
        for c in chats:
            parts.append(f"{c['name']}: " + ". ".join(m[:200] for m in c["messages"]) + ".")
        speech = " ".join(parts)
        if len(speech) > 900 and self.brain_ok:
            speech = parts[0] + " " + self.brain.summarize("\n".join(parts[1:]))
        self.say(speech)
        for c in chats:
            try:
                self.tg.mark_read(c["chat_id"])
            except Exception:
                pass
        self.last_chat = {"chat_id": chats[0]["chat_id"], "name": chats[0]["name"]}
        if len(chats) == 1:
            self.say(f"Ответить {chats[0]['name']}?")
            self.pending = {"type": "reply_text", "chat": self.last_chat}

    def announce_notifications(self):
        got = []
        while True:
            try:
                got.append(self.notifications.get_nowait())
            except queue.Empty:
                break
        if not got or not self.cfg.get("announce_messages", True):
            return
        if self.pending or self.dictation:
            for n in got:
                self.notifications.put(n)
            return
        if len(got) == 1:
            n = got[0]
            self.say(f"Сообщение от {n['name']}: {n['text'][:300]}")
        else:
            names = ", ".join(dict.fromkeys(n["name"] for n in got))
            self.say(f"{len(got)} новых сообщения от: {names}. Скажите «сообщения», чтобы прочитать.")
        last = got[-1]
        self.last_chat = {"chat_id": last["chat_id"], "name": last["name"]}
        self.keep_listening()

    # ------------------------------------------------------------------ reports
    def report(self):
        parts = [actions.system_status()]
        if self.tg:
            try:
                chats = self.tg.unread()
                if chats:
                    names = ", ".join(c["name"] for c in chats)
                    parts.append(f"В телеграме непрочитанные от: {names}. Скажите «сообщения», чтобы прочитать.")
                else:
                    parts.append("Новых сообщений в телеграме нет.")
            except Exception as e:
                parts.append(f"Телеграм не ответил: {e}.")
        self.say(" ".join(parts))

    def periodic_report(self):
        if not self.tg or self.pending or self.dictation:
            return
        try:
            chats = self.tg.unread()
        except Exception:
            return
        if chats:
            names = ", ".join(c["name"] for c in chats)
            self.say(f"Напоминаю: есть непрочитанные сообщения от {names}.")

    # ------------------------------------------------------------------ AI
    def ask_brain(self, text):
        if not self.brain_ok:
            self.say("Не понял команду, а ИИ сейчас не запущен. Скажите «помощь», чтобы услышать команды.")
            return True
        ctx = f"Последний чат в Telegram: {self.last_chat['name']}." if self.last_chat else ""
        plan = self.brain.plan(text, ctx)
        if plan.get("say"):
            self.say(plan["say"])
        for a in plan["actions"]:
            self.run_brain_action(a.get("name"), a.get("args") or {})
        return True

    def run_brain_action(self, name, args):
        mapping = {
            "open_app": lambda: {"intent": "open", "name": args.get("name", "")},
            "open_url": lambda: {"intent": "url", "url": args.get("url", "")},
            "web_search": lambda: {"intent": "search", "query": args.get("query", "")},
            "youtube": lambda: {"intent": "youtube", "query": args.get("query", "")},
            "type_text": lambda: {"intent": "type", "text": args.get("text", "")},
            "hotkey": lambda: {"intent": "hotkey", "keys": args.get("keys") or []},
            "scroll": lambda: {"intent": "scroll", "direction": args.get("direction", "down"),
                               "amount": args.get("amount", 5)},
            "volume": lambda: {"intent": "volume", "direction": args.get("direction", "up")},
            "media": lambda: {"intent": "media", "key": args.get("key", "playpause")},
            "tg_send": lambda: {"intent": "tg_send", "contact": args.get("contact", ""),
                                "text": args.get("text", "")},
            "tg_unread": lambda: {"intent": "tg_unread"},
            "tg_call": lambda: {"intent": "tg_call", "contact": args.get("contact", "")},
            "report": lambda: {"intent": "report"},
            "time": lambda: {"intent": "time"},
            "lock": lambda: {"intent": "lock"},
        }
        if name not in mapping:
            print("ИИ предложил неизвестное действие:", name, args)
            return
        cmd = mapping[name]()
        if cmd["intent"] == "hotkey" and not cmd["keys"]:
            return
        try:
            self.execute_intent(cmd)
        except KeyError as e:
            print("Ошибка в действии ИИ:", name, args, e)


def main():
    cfg = load_config()
    Jarvis(cfg).run()


if __name__ == "__main__":
    main()
