"""Слух (Vosk, офлайн) и голос (Edge TTS онлайн, при сбое — голос Windows)."""
import asyncio
import ctypes
import json
import os
import queue
import tempfile
import threading
import time

import sounddevice as sd
from vosk import KaldiRecognizer, Model, SetLogLevel

SetLogLevel(-1)


class Listener:
    def __init__(self, model_path, device=None, samplerate=16000):
        self.model = Model(model_path)
        self.rate = samplerate
        self.q = queue.Queue()
        self.muted = threading.Event()
        self.rec = KaldiRecognizer(self.model, self.rate)
        self.stream = sd.RawInputStream(samplerate=self.rate, blocksize=4000, dtype="int16",
                                        channels=1, device=device, callback=self._cb)
        self.stream.start()

    def _cb(self, indata, frames, t, status):
        if not self.muted.is_set():
            self.q.put(bytes(indata))

    def flush(self):
        while True:
            try:
                self.q.get_nowait()
            except queue.Empty:
                break
        self.rec.Reset()

    def listen(self, timeout=None):
        """Ждёт законченную фразу. Возвращает текст или None, если за timeout ничего не сказали."""
        deadline = time.time() + timeout if timeout else None
        while True:
            if deadline is not None and time.time() >= deadline:
                partial = json.loads(self.rec.PartialResult()).get("partial", "")
                if not partial:
                    return None
                deadline = time.time() + 0.5  # человек ещё говорит — ждём
            try:
                data = self.q.get(timeout=0.25)
            except queue.Empty:
                continue
            if self.rec.AcceptWaveform(data):
                text = json.loads(self.rec.Result()).get("text", "").strip()
                if text:
                    return text


def _play_mp3(path):
    mci = ctypes.windll.winmm.mciSendStringW
    mci('close jarvis_tts', None, 0, 0)
    mci(f'open "{path}" type mpegvideo alias jarvis_tts', None, 0, 0)
    mci('play jarvis_tts wait', None, 0, 0)
    mci('close jarvis_tts', None, 0, 0)


class Speaker:
    def __init__(self, listener, voice="ru-RU-DmitryNeural", rate="+10%", use_online=True):
        self.listener = listener
        self.voice = voice
        self.rate = rate
        self.use_online = use_online
        self.lock = threading.Lock()

    def say(self, text):
        text = (text or "").strip()
        if not text:
            return
        print(f"Джарвис: {text}", flush=True)
        with self.lock:
            if self.listener:
                self.listener.muted.set()
            try:
                done = False
                if self.use_online:
                    try:
                        self._edge(text)
                        done = True
                    except Exception as e:  # нет интернета и т.п.
                        print(f"[голос онлайн недоступен: {e}]")
                if not done:
                    self._sapi(text)
            finally:
                time.sleep(0.15)
                if self.listener:
                    self.listener.flush()
                    self.listener.muted.clear()

    def _edge(self, text):
        import edge_tts
        fd, path = tempfile.mkstemp(suffix=".mp3", prefix="jarvis_")
        os.close(fd)
        try:
            asyncio.run(edge_tts.Communicate(text, self.voice, rate=self.rate).save(path))
            _play_mp3(path)
        finally:
            try:
                os.remove(path)
            except OSError:
                pass

    def _sapi(self, text):
        import pyttsx3
        engine = pyttsx3.init()
        for v in engine.getProperty("voices"):
            name = (v.name or "") + " " + str(getattr(v, "languages", ""))
            if any(k in name.lower() for k in ("russian", "irina", "pavel", "ru-ru", "ru_ru")):
                engine.setProperty("voice", v.id)
                break
        engine.say(text)
        engine.runAndWait()
        engine.stop()
