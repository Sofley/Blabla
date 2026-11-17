"""Обновление Джарвиса с GitHub. Ваши настройки, модели, Telegram, записи и картинки сохраняются.

Запуск: update.bat или голосом «Джарвис, обновись».
"""
import io
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "sofley/blabla"
BRANCH = "claude/confident-brown-r8uh4o"
URL = f"https://codeload.github.com/{REPO}/zip/refs/heads/{BRANCH}"

# Это остаётся как есть: личное и тяжёлое
KEEP = {"config.json", "telegram.session", "telegram.session-journal", ".venv", "models", ".window_profile"}
KEEP_DIRS_INSIDE = {os.path.join("voices", "custom"), os.path.join("voices", "piper"),
                    os.path.join("voices", "installed.json"), os.path.join("ui", "user")}


def keep(rel):
    top = rel.split(os.sep)[0]
    if top in KEEP:
        return True
    return any(rel == d or rel.startswith(d + os.sep) for d in KEEP_DIRS_INSIDE)


def main():
    print("Скачиваю свежую версию Джарвиса...", flush=True)
    data = urllib.request.urlopen(URL, timeout=120).read()
    z = zipfile.ZipFile(io.BytesIO(data))
    prefix = None
    for name in z.namelist():
        parts = name.split("/")
        if len(parts) > 2 and parts[1] == "jarvis":
            prefix = parts[0] + "/jarvis/"
            break
    if not prefix:
        raise SystemExit("В архиве нет папки jarvis")
    updated = 0
    for name in z.namelist():
        if not name.startswith(prefix) or name.endswith("/"):
            continue
        rel = os.path.normpath(name[len(prefix):])
        if keep(rel):
            continue
        dst = os.path.join(HERE, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        new = z.read(name)
        try:
            with open(dst, "rb") as f:
                if f.read() == new:
                    continue
        except OSError:
            pass
        with open(dst, "wb") as f:
            f.write(new)
        updated += 1
        print("  обновлён:", rel)
    print(f"Файлов обновлено: {updated}.")
    if updated:
        print("Проверяю библиотеки...", flush=True)
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "-r", os.path.join(HERE, "requirements.txt")])
    shutil.rmtree(os.path.join(HERE, "__pycache__"), ignore_errors=True)
    return updated


if __name__ == "__main__":
    n = main()
    sys.exit(0 if n >= 0 else 1)
