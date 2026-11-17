"""Telegram от вашего имени (Telethon): чтение, ответы, поиск контактов, открытие чата для звонка."""
import asyncio
import difflib
import os
import threading

from telethon import TelegramClient, events, utils


def _name(entity):
    return utils.get_display_name(entity) or "без имени"


def _norm(s):
    return (s or "").lower().replace("ё", "е").strip()


class TelegramAgent:
    def __init__(self, api_id, api_hash, session_path, on_message, announce_groups=False):
        self.api_id = int(api_id)
        self.api_hash = api_hash
        self.session_path = session_path
        self.on_message = on_message
        self.announce_groups = announce_groups
        self.client = None
        self.me = None
        self.loop = asyncio.new_event_loop()
        threading.Thread(target=self._run_loop, daemon=True).start()

    def _run_loop(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()

    def _call(self, coro, timeout=60):
        return asyncio.run_coroutine_threadsafe(coro, self.loop).result(timeout)

    # ---------- запуск
    def start(self):
        return self._call(self._start())

    async def _start(self):
        self.client = TelegramClient(self.session_path, self.api_id, self.api_hash)
        await self.client.connect()
        if not await self.client.is_user_authorized():
            raise RuntimeError("Telegram не подключён. Запустите setup_telegram.bat")
        self.me = await self.client.get_me()
        self.client.add_event_handler(self._on_new, events.NewMessage(incoming=True))
        return _name(self.me)

    async def _on_new(self, event):
        if event.is_private:
            sender = await event.get_sender()
            if getattr(sender, "bot", False):
                return
            title = _name(sender)
        elif self.announce_groups and event.is_group:
            chat = await event.get_chat()
            sender = await event.get_sender()
            title = f"{_name(sender)} в группе {_name(chat)}"
        else:
            return
        text = event.raw_text or self._media_label(event.message)
        self.on_message({"chat_id": event.chat_id, "name": title, "text": text})

    @staticmethod
    def _media_label(msg):
        if msg.voice:
            return "голосовое сообщение"
        if msg.photo:
            return "фотография"
        if msg.video or msg.video_note:
            return "видео"
        if msg.sticker:
            return "стикер"
        if msg.document:
            return "файл"
        return "сообщение без текста"

    # ---------- поиск получателя
    def find_chat(self, spoken_name):
        return self._call(self._find_chat(spoken_name))

    async def _find_chat(self, spoken_name):
        target = _norm(spoken_name)
        # «маме», «сергею», «с андреем» -> основа слова
        target = target[2:] if target.startswith("с ") else target
        stem = target.split()[0][:-2] if target.split() and len(target.split()[0]) >= 5 else target
        best, best_score = None, 0.0
        async for d in self.client.iter_dialogs(limit=300):
            names = {_norm(d.name)}
            ent = d.entity
            for attr in ("first_name", "last_name", "username"):
                v = getattr(ent, attr, None)
                if v:
                    names.add(_norm(v))
            for n in names:
                if not n:
                    continue
                if n == target:
                    score = 1.0
                elif target in n.split() or (len(target) > 3 and n.startswith(target)):
                    score = 0.9
                elif len(stem) >= 3 and any(w.startswith(stem) for w in n.split()):
                    score = 0.8
                else:
                    score = difflib.SequenceMatcher(None, target, n).ratio()
                if score > best_score:
                    best, best_score = d, score
        if best and best_score >= 0.6:
            return {"chat_id": best.id, "name": best.name,
                    "username": getattr(best.entity, "username", None),
                    "phone": getattr(best.entity, "phone", None)}
        return None

    # ---------- чтение
    def unread(self, max_chats=6, per_chat=3):
        return self._call(self._unread(max_chats, per_chat), timeout=120)

    async def _unread(self, max_chats, per_chat):
        result = []
        async for d in self.client.iter_dialogs(limit=100):
            if d.unread_count <= 0 or d.archived:
                continue
            if not d.is_user and not self.announce_groups:
                continue
            if d.is_user and getattr(d.entity, "bot", False):
                continue
            msgs = []
            async for m in self.client.iter_messages(d.entity, limit=min(d.unread_count, per_chat)):
                msgs.append(m.raw_text or self._media_label(m))
            result.append({"chat_id": d.id, "name": d.name, "count": d.unread_count,
                           "messages": list(reversed(msgs))})
            if len(result) >= max_chats:
                break
        return result

    def mark_read(self, chat_id):
        return self._call(self.client.send_read_acknowledge(chat_id))

    def history(self, chat_id, limit=10):
        return self._call(self._history(chat_id, limit))

    async def _history(self, chat_id, limit):
        lines = []
        async for m in self.client.iter_messages(chat_id, limit=limit):
            who = "Я" if m.out else "Собеседник"
            lines.append(f"{who}: {m.raw_text or self._media_label(m)}")
        return list(reversed(lines))

    # ---------- отправка
    def send(self, chat_id, text):
        return self._call(self.client.send_message(chat_id, text))

    # ---------- звонок: открываем чат в Telegram Desktop
    @staticmethod
    def open_chat_in_app(info):
        if info.get("username"):
            os.startfile(f"tg://resolve?domain={info['username']}")
        elif info.get("phone"):
            os.startfile(f"tg://resolve?phone={info['phone']}")
        else:
            os.startfile("tg://")
            return False
        return True
