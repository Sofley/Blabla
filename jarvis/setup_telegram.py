"""Подключение вашего аккаунта Telegram к Джарвису (один раз).

Нужны api_id и api_hash с сайта https://my.telegram.org (раздел API development tools).
Вводить можно экранной клавиатурой.
"""
import json
import os
import sys
import webbrowser

from telethon.sync import TelegramClient

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "config.json")


def main():
    cfg = {}
    if os.path.exists(CONFIG):
        with open(CONFIG, encoding="utf-8") as f:
            cfg = json.load(f)
    tg = cfg.get("telegram") or {}

    if not (tg.get("api_id") and tg.get("api_hash")):
        print("Сейчас откроется сайт my.telegram.org.")
        print("1) Войдите по номеру телефона (код придёт в Telegram).")
        print("2) Нажмите «API development tools», заполните App title (например Jarvis)")
        print("   и Short name (например jarvis), нажмите Create application.")
        print("3) Скопируйте мышкой App api_id и App api_hash и вставьте сюда")
        print("   (правый щелчок мыши в этом окне = вставить).\n")
        webbrowser.open("https://my.telegram.org/apps")
        tg["api_id"] = input("api_id: ").strip()
        tg["api_hash"] = input("api_hash: ").strip()
        if not tg["api_id"].isdigit() or len(tg["api_hash"]) < 20:
            print("Похоже, значения неверные. Запустите ещё раз.")
            input("Нажмите Enter...")
            sys.exit(1)
        tg.setdefault("announce_groups", False)
        cfg["telegram"] = tg
        with open(CONFIG, "w", encoding="utf-8") as f:
            json.dump(cfg, f, ensure_ascii=False, indent=2)

    print("\nТеперь вход в ваш аккаунт. Номер вводите в формате +79991234567.")
    print("Код подтверждения придёт в приложение Telegram.\n")
    client = TelegramClient(os.path.join(HERE, "telegram"), int(tg["api_id"]), tg["api_hash"])
    client.start(phone=lambda: input("Номер телефона: ").strip(),
                 code_callback=lambda: input("Код из Telegram: ").strip(),
                 password=lambda: input("Облачный пароль (если включён): "))
    me = client.get_me()
    print(f"\nГотово! Telegram подключён: {me.first_name}.")
    print("Перезапустите Джарвиса (ярлык на рабочем столе).")
    client.disconnect()
    input("Нажмите Enter, чтобы закрыть...")


if __name__ == "__main__":
    main()
