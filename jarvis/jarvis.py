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
import natural  # noqa: E402
import system_control as SC  # noqa: E402
import voices as V  # noqa: E402
from voice import Listener, Speaker  # noqa: E402

CONFIG_PATH = os.path.join(HERE, "config.json")


def save_config(updates):
    cfg = {}
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as f:
            cfg = json.load(f)
    cfg.update(updates)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)


def load_config():
    with open(os.path.join(HERE, "config.example.json"), encoding="utf-8") as f:
        cfg = json.load(f)
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as f:
            cfg.update(json.load(f))
    return cfg


class Jarvis:
    def __init__(self, cfg, ui=None):
        self.cfg = cfg
        model_dir = os.path.join(HERE, cfg["vosk_model"])
        if not os.path.isdir(model_dir):
            raise SystemExit("Нет модели распознавания речи. Запустите install.bat")
        self.ear = Listener(model_dir, device=cfg.get("microphone"))
        self.ui = ui
        self.address = cfg.get("address", "сэр")
        self.presets = V.all_presets()
        self.new_voices = []
        self.preset_idx = min(max(int(cfg.get("voice_preset", 1)), 1), len(self.presets)) - 1
        self.voice = Speaker(self.ear, self.presets[self.preset_idx], ui=ui,
                             custom_dir=os.path.join(HERE, "voices", "custom"),
                             elevenlabs=cfg.get("elevenlabs"))
        self.brain = Brain(cfg["llm_model"], cfg.get("ollama_host", "http://127.0.0.1:11434"), self.address)
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
    def say(self, text, key=None):
        self.voice.say(text, key=key)

    def P(self, key, **kw):
        """Фирменная фраза Джарвиса (с вашей записью, если она есть)."""
        self.say(V.phrase(key, self.address), key=key)

    def mode(self, m, text=None):
        if self.ui:
            self.ui.set_mode(m, text)

    def keep_listening(self):
        self.active_until = time.time() + self.follow_up

    def boot(self, text, status="..."):
        if self.ui and hasattr(self.ui, "boot_step"):
            self.ui.boot_step(text, status)

    def start_services(self):
        self.boot("Распознавание речи", "готово")
        self.boot("Голос: " + self.voice.preset.get("name", ""), "готово")
        self.boot("Искусственный интеллект")
        self.brain_ok = self.brain.ensure_running()
        self.boot("Искусственный интеллект", "готово" if self.brain_ok else "нет связи")
        if self.ui and hasattr(self.ui, "set_ai"):
            self.ui.set_ai(self.brain_ok)
        if self.brain_ok:
            print("ИИ (Ollama) запущен, модель:", self.brain.model)
            self.brain.warm_up()
        else:
            print("ВНИМАНИЕ: Ollama не запущена — сложные вопросы недоступны, простые команды работают.")

        tg = self.cfg.get("telegram") or {}
        if not (tg.get("api_id") and tg.get("api_hash")):
            self.boot("Telegram", "не подключён")
        if tg.get("api_id") and tg.get("api_hash"):
            self.boot("Telegram")
            try:
                from telegram_agent import TelegramAgent
                self.tg = TelegramAgent(tg["api_id"], tg["api_hash"], os.path.join(HERE, "telegram"),
                                        self.notifications.put, tg.get("announce_groups", False))
                me = self.tg.start()
                print("Telegram подключён:", me)
                self.boot("Telegram", "подключён")
            except Exception as e:
                print("Telegram не подключился:", e)
                self.boot("Telegram", "ошибка")
                self.tg = None
        self.boot("Все системы", "в норме")
        time.sleep(1.2)

    # ------------------------------------------------------------------ main loop
    def run(self):
        self.start_services()
        if self.ui and hasattr(self.ui, "boot_done"):
            self.ui.boot_done()
        self.P("greeting")
        if self.ui and hasattr(self.ui, "dock"):
            self.ui.dock()
        if not self.brain_ok and self.ui and hasattr(self.ui, "show_hints") and self.cfg.get("hints_without_ai", True):
            self.ui.show_hints(True)
        report_every = float(self.cfg.get("report_every_minutes", 0)) * 60
        next_report = time.time() + report_every if report_every else None

        while True:
            listening = time.time() < self.active_until or self.pending or self.dictation
            if self.ui and self.ui.mode != "speaking":
                self.ui.mode = "listening" if listening else "idle"
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
                    self.P("listening")
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
                self.say(V.phrase("error", self.address) + f" {e}", key="error")

    # ------------------------------------------------------------------ dictation
    def handle_dictation(self, text):
        _, rest = C.strip_wake(text, self.wake)
        if rest in {"стоп диктовка", "стоп", "закончить диктовку", "конец диктовки", "хватит"} or \
                text in {"стоп диктовка", "конец диктовки", "закончить диктовку"}:
            self.dictation = False
            self.P("dictation_off")
            self.keep_listening()
            return
        cmd = C.parse(rest) if rest != text else None  # «Джарвис нажми энтер» во время диктовки
        if cmd and cmd["intent"] in {"hotkey", "scroll", "click"}:
            self.execute_intent(cmd)
            return
        typed, self.dict_cap = C.dictation_text(text, self.dict_cap)
        actions.type_text(typed)

    # ------------------------------------------------------------------ confirmations
    def ask_permission(self, question, do, done="Готово", cancel=None):
        """Спросить «да/нет» и выполнить действие только после согласия."""
        self.pending = {"type": "action", "do": do, "done": done}
        self.say(question)

    def handle_pending(self, text):
        p = self.pending
        if p["type"] == "choose":
            n = V.parse_number(text)
            if n is None and C.is_yes(text):
                n = 1
            if C.is_no(text) or n is None or not 1 <= n <= len(p["items"]):
                self.pending = None
                if not C.is_no(text) and n is not None:
                    self.say("Такого номера нет.")
                self.P("cancelled")
                return
            self.pending = None
            self.open_found(p["items"][n - 1], confirmed=True)
            return
        if p["type"] == "action":
            self.pending = None
            if C.is_yes(text):
                try:
                    result = p["do"]()
                    self.say(result if isinstance(result, str) else p["done"])
                except Exception as e:
                    self.say(f"Не получилось: {e}")
            else:
                self.P("cancelled")
            self.keep_listening()
            return
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
                self.P("sent")
            elif p["type"] == "shutdown":
                self.say("Выключаю компьютер.")
                actions.shutdown()
            elif p["type"] == "restart":
                self.say("Перезагружаю.")
                actions.restart()
            self.keep_listening()
        elif C.is_no(text):
            self.pending = None
            self.P("cancelled")
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
    def heard(self, text, understood):
        if self.ui and hasattr(self.ui, "heard"):
            self.ui.heard(text, understood)

    def handle(self, text):
        cmd, _ = natural.understand(text, ai_available=self.brain_ok)
        self.heard(text, bool(cmd) or self.brain_ok)
        if cmd:
            return self.execute_intent(cmd)
        return self.ask_brain(text)

    def execute_intent(self, cmd):
        i = cmd["intent"]
        if i == "stop":
            self.P("stop")
            return False
        if i == "exit":
            self.P("bye")
            os._exit(0)
        if i == "update":
            self.say("Скачиваю обновление и перезапускаюсь. Это займёт около минуты.")
            import subprocess
            subprocess.Popen(["cmd", "/c", "start", "", os.path.join(HERE, "update.bat")], cwd=HERE)
            os._exit(0)
        if i in ("help", "hints_show"):
            if self.ui and hasattr(self.ui, "show_hints"):
                self.ui.show_hints(True)
                self.say("Открыл подсказки рядом со мной. Говорите своими словами, это только примеры"
                         f"{V.address_suffix(self.address)}.")
            else:
                self.say(C.HELP)
        elif i == "settings_open":
            uri, name = SC.settings_page(cmd.get("topic", ""))
            SC.open_settings(uri)
            self.say(f"Открываю настройки: {name}.")
        elif i == "set_theme":
            what = "тёмную" if cmd["dark"] else "светлую"
            self.ask_permission(f"Включить {what} тему Windows{V.address_suffix(self.address)}?",
                                lambda: SC.set_theme(cmd["dark"]), done=f"Включил {what} тему.")
        elif i == "brightness":
            new = SC.set_brightness(level=cmd.get("level"), delta=cmd.get("delta"))
            if new is None:
                SC.open_settings("ms-settings:display")
                self.say("Голосом яркость этого экрана не меняется. Открыл настройки экрана.")
            else:
                self.say(f"Яркость {new} процентов.")
        elif i == "file_open":
            self.find_and_open(cmd)
        elif i == "hints_hide":
            if self.ui and hasattr(self.ui, "show_hints"):
                self.ui.show_hints(False)
            self.P("done")
        elif i == "dictation_on":
            self.dictation = True
            self.dict_cap = True
            self.P("dictation_on")
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
            self.P("opening")
        elif i == "open":
            actions.open_app(cmd["name"])
            self.P("opening")
        elif i == "search":
            actions.web_search(cmd["query"], self.cfg.get("search_engine", "google"))
            if cmd.get("fallback"):
                self.say(f"Ищу ответ в интернете{V.address_suffix(self.address)}.")
            else:
                self.P("searching")
        elif i == "youtube":
            actions.youtube(cmd["query"])
            self.P("youtube")
        elif i.startswith("tg_"):
            return self.telegram_intent(cmd)
        elif i.startswith("voice_"):
            self.voice_intent(cmd)
        elif i == "theme":
            if self.ui and self.ui.set_theme(cmd["name"]):
                save_config({"theme": cmd["name"]})
                self.P("done")
            else:
                self.say("Доступные цвета: голубой, золотой, красный, зелёный, фиолетовый.")
        elif i == "scene":
            if self.ui and hasattr(self.ui, "set_scene") and self.ui.set_scene(cmd["name"]):
                save_config({"scene": cmd["name"]})
                self.say({"mirror": "Режим Шрека: перемещаюсь в волшебное зеркало.",
                          "panda": "Режим панды включён.",
                          "tube": "Возвращаюсь в командный центр."}[cmd["name"]])
            else:
                self.say("Сцены есть только в объёмном окне.")
        elif i == "hide":
            if self.ui:
                self.ui.hide()
            self.say("Ухожу в тень. Скажите «покажись», и я вернусь.")
        elif i == "show":
            if self.ui:
                self.ui.show()
            self.P("listening")
        return True

    # ------------------------------------------------------------------ файлы
    def find_and_open(self, cmd):
        what = "папку" if cmd.get("folder") else "файл"
        self.say(f"Ищу {what} «{cmd['name']}».")
        self.mode("thinking", f"ищу {what} {cmd['name']}")
        kinds = SC.DOC_HINT.get(cmd.get("kind")) if cmd.get("kind") else None
        found = [p for p, _ in SC.find(cmd["name"], folders_only=bool(cmd.get("folder")), kinds=kinds)]
        if not found:
            self.say(f"Не нашёл {what} «{cmd['name']}» на рабочем столе, в документах, загрузках и на дисках.")
            return
        if len(found) == 1:
            self.open_found(found[0])
            return
        self.pending = {"type": "choose", "items": found}
        listing = "; ".join(f"{k + 1} — {SC.describe(p)}" for k, p in enumerate(found))
        self.say(f"Нашёл несколько: {listing}. Какой открыть? Скажите номер или «нет».")

    def open_found(self, path, confirmed=False):
        desc = SC.describe(path)
        if SC.is_risky(path):
            self.ask_permission(f"{desc} — это программа или скрипт. Запустить её{V.address_suffix(self.address)}?",
                                lambda: SC.open_path(path), done="Запускаю.")
        elif confirmed:
            SC.open_path(path)
            self.P("opening")
        else:
            self.ask_permission(f"Нашёл {desc}. Открыть?", lambda: SC.open_path(path), done="Открываю.")

    # ------------------------------------------------------------------ voices
    def set_voice(self, idx, announce=True):
        self.presets = V.all_presets()
        self.preset_idx = idx % len(self.presets)
        preset = self.presets[self.preset_idx]
        if preset.get("engine") == "piper":
            import voice_store
            if not os.path.exists(voice_store.piper_paths(preset["model"])[0]):
                self.say("Скачиваю этот голос из интернета, около минуты.")
                voice_store.ensure_piper_model(preset["model"])
        self.voice.preset = preset
        save_config({"voice_preset": self.preset_idx + 1})
        if announce:
            self.say(f"Голос номер {self.preset_idx + 1}, «{preset['name']}». Так лучше{V.address_suffix(self.address)}?")

    def demo_voices(self, numbered):
        for k, p in numbered:
            if p["engine"] == "elevenlabs" and not (self.cfg.get("elevenlabs") or {}).get("api_key"):
                continue
            if p["engine"] == "piper":
                import voice_store
                if not os.path.exists(voice_store.piper_paths(p["model"])[0]):
                    self.say(f"Голос номер {k + 1}, «{p['name']}», скачиваю…")
                    try:
                        voice_store.ensure_piper_model(p["model"])
                    except Exception as e:
                        self.say(f"Не скачался: {e}")
                        continue
            self.voice.say(f"Голос номер {k + 1}. " + V.SAMPLE.format(a=V.address_suffix(self.address)), preset=p)

    def voice_intent(self, cmd):
        import voice_store
        i = cmd["intent"]
        self.presets = V.all_presets()
        if i == "voice_next":
            self.set_voice(self.preset_idx + 1)
        elif i == "voice_set":
            n = V.parse_number(cmd["number"])
            if not n or n > len(self.presets):
                self.say(f"Есть голоса с первого по {len(self.presets)}-й.")
            else:
                self.set_voice(n - 1)
        elif i == "voice_list":
            names = "; ".join(f"{k + 1} — {p['name']}" for k, p in enumerate(self.presets))
            self.say(f"Доступные голоса: {names}. Скажите, например, «голос номер три».")
        elif i == "voice_demo":
            self.say("Сейчас каждый голос представится. Запомните номер того, что понравится.")
            self.demo_voices(list(enumerate(self.presets)))
            self.say("Это все голоса. Скажите «голос номер» и цифру.")
        elif i == "voice_fetch":
            self.P("thinking")
            self.mode("thinking", "ищу новые голоса")
            new = voice_store.discover(V.PRESETS)
            self.presets = V.all_presets()
            if not new:
                self.say(f"Новых голосов пока нет{V.address_suffix(self.address)}. Всего голосов: {len(self.presets)}.")
                return
            first = len(self.presets) - len(new)
            self.new_voices = list(range(first, len(self.presets)))
            self.say(f"Нашёл новых голосов: {len(new)}. Они под номерами с {first + 1} по {len(self.presets)}. "
                     "Скажите «прослушать новые голоса» или «голос номер» и цифру.")
        elif i == "voice_demo_new":
            if not self.new_voices:
                self.say("Новых голосов нет. Скажите «загрузи новые голоса».")
                return
            self.demo_voices([(k, self.presets[k]) for k in self.new_voices if k < len(self.presets)])
            self.say("Это все новые голоса. Скажите «голос номер» и цифру.")
        elif i == "voice_get":
            self.mode("thinking", "ищу голос " + cmd["name"])
            p = voice_store.search_online(cmd["name"], V.PRESETS)
            if not p:
                self.say(f"Не нашёл голос «{cmd['name']}». Скажите «загрузи новые голоса», чтобы получить все.")
                return
            self.presets = V.all_presets()
            self.set_voice(next(k for k, x in enumerate(self.presets) if voice_store._key(x) == voice_store._key(p)))

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
        self.say(f"Сообщение для «{chat['name']}»: {text}. Отправить{V.address_suffix(self.address)}?")

    def draft_reply(self, chat, hint=""):
        if not self.brain_ok:
            self.say("ИИ не запущен, скажите текст ответа сами.")
            self.pending = {"type": "reply_text", "chat": chat}
            return
        self.P("thinking")
        self.mode("thinking")
        hist = self.tg.history(chat["chat_id"])
        text = self.brain.draft_reply(chat["name"], hist, hint)
        self.confirm_send(chat, text)

    def read_unread(self):
        chats = self.tg.unread()
        if not chats:
            self.P("no_messages")
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
            self.say(f"Ответить{V.address_suffix(self.address)}?")
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
            if self.ui and hasattr(self.ui, "show_hints"):
                self.ui.show_hints(True)
            self.say(f"Простите{V.address_suffix(self.address)}, не расслышал. Скажите иначе — "
                     "примеры я показал рядом.")
            return True
        ctx = f"Последний чат в Telegram: {self.last_chat['name']}." if self.last_chat else ""
        self.mode("thinking", text)
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
            "open_settings": lambda: {"intent": "settings_open", "topic": str(args.get("topic", ""))},
            "set_theme": lambda: {"intent": "set_theme", "dark": bool(args.get("dark", True))},
            "brightness": lambda: {"intent": "brightness", "level": args.get("level"), "delta": args.get("delta")},
            "open_file": lambda: {"intent": "file_open", "name": str(args.get("name", "")),
                                  "folder": bool(args.get("folder"))},
            "scene": lambda: {"intent": "scene", "name": args.get("name", "mirror")},
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
    ui = None
    if cfg.get("show_window", True):
        try:
            if cfg.get("window_style", "hologram") == "hologram":
                from ui_server import WebAvatar
                ui = WebAvatar(cfg.get("theme", ""), int(cfg.get("ui_port", 8765)), scene=cfg.get("scene", "mirror"),
                               intro=bool(cfg.get("intro", True)))
            else:
                from avatar import AvatarWindow
                ui = AvatarWindow(cfg.get("theme", "голубой"))
        except Exception as e:  # нет графики — работаем без окна
            print("Окно Джарвиса не открылось:", e)
            ui = None
    if ui is None:
        Jarvis(cfg).run()
        return

    import threading

    def worker():
        try:
            Jarvis(cfg, ui).run()
        except BaseException:
            traceback.print_exc()
        finally:
            os._exit(1)

    threading.Thread(target=worker, daemon=True).start()
    ui.run()


if __name__ == "__main__":
    main()
