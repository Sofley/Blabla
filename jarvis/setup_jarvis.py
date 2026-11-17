"""Вторая часть установки (её запускает install.bat): модель речи, модель ИИ, настройки, ярлыки."""
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

VOSK_NAME = "vosk-model-small-ru-0.22"
VOSK_URL = f"https://alphacephei.com/vosk/models/{VOSK_NAME}.zip"


def step(msg):
    print("\n=== " + msg, flush=True)


def download_vosk():
    target = os.path.join(HERE, "models", VOSK_NAME)
    if os.path.isdir(target):
        print("Модель речи уже скачана.")
        return
    os.makedirs(os.path.join(HERE, "models"), exist_ok=True)
    zpath = os.path.join(HERE, "models", VOSK_NAME + ".zip")

    def hook(blocks, bs, total):
        if total > 0:
            print(f"\r  скачано {min(100, blocks * bs * 100 // total)}%", end="", flush=True)

    urllib.request.urlretrieve(VOSK_URL, zpath, hook)
    print()
    with zipfile.ZipFile(zpath) as z:
        z.extractall(os.path.join(HERE, "models"))
    os.remove(zpath)


def pick_llm():
    import psutil
    gb = psutil.virtual_memory().total / 1024 ** 3
    model = "qwen2.5:7b" if gb >= 12 else "qwen2.5:3b"
    print(f"Оперативной памяти: {gb:.0f} ГБ -> модель ИИ {model}")
    return model


def setup_ollama(model):
    from brain import Brain, find_ollama
    b = Brain(model)
    if not b.ensure_running(wait=60):
        print("!! Ollama не запустилась. Перезагрузите компьютер и запустите install.bat ещё раз.")
        return False
    exe = find_ollama()
    print(f"Скачиваю модель {model} (несколько гигабайт, это надолго)...")
    from brain import ollama_env
    subprocess.run([exe, "pull", model], check=False, env=ollama_env())
    return True


def download_fallback_voice():
    try:
        import voice_store
        print("Скачиваю офлайн-голос «Дмитрий» (~60 МБ)...")
        voice_store.ensure_piper_model("ru_RU-dmitri-medium")
    except Exception as e:
        print("!! Офлайн-голос не скачался:", e)


def write_config(model):
    path = os.path.join(HERE, "config.json")
    cfg = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            cfg = json.load(f)
    cfg.setdefault("llm_model", model)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)


def shortcuts():
    bat = os.path.join(HERE, "start_jarvis.bat")
    ps = r"""
$s = New-Object -ComObject WScript.Shell
$targets = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Startup'))
foreach ($d in $targets) {
  $l = $s.CreateShortcut((Join-Path $d 'Джарвис.lnk'))
  $l.TargetPath = '%BAT%'
  $l.WorkingDirectory = '%DIR%'
  $l.WindowStyle = 7
  $l.IconLocation = 'shell32.dll,138'
  $l.Save()
}
""".replace("%BAT%", bat).replace("%DIR%", HERE)
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps], check=False)
    print("Ярлык «Джарвис» создан на рабочем столе и в автозагрузке (запускается при включении ПК).")


def check_mic():
    import sounddevice as sd
    try:
        dev = sd.query_devices(kind="input")
        print("Микрофон:", dev["name"])
    except Exception as e:
        print("!! Микрофон не найден:", e)


def main():
    step("1/5 Модель распознавания русской речи (~45 МБ)")
    download_vosk()
    step("2/5 Выбор модели ИИ")
    model = pick_llm()
    step("3/5 Модель ИИ в Ollama")
    setup_ollama(model)
    step("4/5 Настройки и офлайн-голос")
    write_config(model)
    download_fallback_voice()
    check_mic()
    step("5/5 Ярлыки")
    shortcuts()
    print("\nГОТОВО! Джарвис запустится через 5 секунд.")
    print("Подключить Telegram: дважды щёлкните setup_telegram.bat в папке Джарвиса.")
    time.sleep(5)


if __name__ == "__main__":
    main()
