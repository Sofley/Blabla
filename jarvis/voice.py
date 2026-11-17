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


def _mci(cmd):
    buf = ctypes.create_unicode_buffer(256)
    ctypes.windll.winmm.mciSendStringW(cmd, buf, 255, 0)
    return buf.value


def play_file(path, on_start=None):
    """Проигрывает mp3/wav. on_start(длительность_мс) вызывается перед началом звука."""
    _mci("close jarvis_tts")
    kind = "waveaudio" if path.lower().endswith(".wav") else "mpegvideo"
    _mci(f'open "{path}" type {kind} alias jarvis_tts')
    _mci("set jarvis_tts time format milliseconds")
    try:
        length = int(_mci("status jarvis_tts length") or 0)
    except ValueError:
        length = 0
    if on_start:
        on_start(length)
    _mci("play jarvis_tts wait")
    _mci("close jarvis_tts")


class Speaker:
    """Говорит выбранным голосом. ui — окно с анимацией (может быть None)."""

    def __init__(self, listener, preset, ui=None, custom_dir=None, elevenlabs=None):
        self.listener = listener
        self.preset = preset
        self.ui = ui
        self.custom_dir = custom_dir
        self.elevenlabs = elevenlabs or {}
        self.lock = threading.Lock()

    def _ui(self, method, *args):
        if self.ui:
            try:
                getattr(self.ui, method)(*args)
            except Exception:
                pass

    def say(self, text, key=None, preset=None):
        """key — имя фирменной фразы: если есть ваша запись voices/custom/<key>.mp3, играет она."""
        text = (text or "").strip()
        if not text:
            return
        print(f"Джарвис: {text}", flush=True)
        preset = preset or self.preset
        with self.lock:
            if self.listener:
                self.listener.muted.set()
            try:
                from voices import custom_phrase_file
                own = custom_phrase_file(self.custom_dir, key) if key else None
                if own:
                    play_file(own, lambda ms: self._ui("speaking", text, ms))
                else:
                    self._speak_tts(text, preset)
            finally:
                self._ui("idle")
                time.sleep(0.15)
                if self.listener:
                    self.listener.flush()
                    self.listener.muted.clear()

    def _speak_tts(self, text, preset):
        engine = preset.get("engine", "edge")
        if engine in ("edge", "elevenlabs", "piper"):
            try:
                path = self._synth(text, preset)
                try:
                    play_file(path, lambda ms: self._ui("speaking", text, ms))
                finally:
                    try:
                        os.remove(path)
                    except OSError:
                        pass
                return
            except Exception as e:
                print(f"[голос «{preset.get('name')}» недоступен: {e}; говорю голосом Windows]")
        self._ui("speaking", text, len(text) * 70)
        self._sapi(text)

    def _synth(self, text, preset):
        if preset["engine"] == "piper":
            import voice_store
            voice_store.ensure_piper_model(preset["model"])
            fd, path = tempfile.mkstemp(suffix=".wav", prefix="jarvis_")
            os.close(fd)
            voice_store.piper_synth(preset["model"], text, path, preset.get("rate", 1.0))
            return path
        fd, path = tempfile.mkstemp(suffix=".mp3", prefix="jarvis_")
        os.close(fd)
        if preset["engine"] == "elevenlabs":
            import requests
            key, vid = self.elevenlabs.get("api_key"), self.elevenlabs.get("voice_id")
            if not key or not vid:
                raise RuntimeError("в config.json не заполнены elevenlabs.api_key и voice_id")
            r = requests.post(f"https://api.elevenlabs.io/v1/text-to-speech/{vid}",
                              headers={"xi-api-key": key},
                              json={"text": text, "model_id": self.elevenlabs.get("model", "eleven_multilingual_v2")},
                              timeout=60)
            r.raise_for_status()
            with open(path, "wb") as f:
                f.write(r.content)
        else:
            import edge_tts
            asyncio.run(edge_tts.Communicate(text, preset["voice"], rate=preset.get("rate", "+0%"),
                                             pitch=preset.get("pitch", "+0Hz")).save(path))
        return path

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
