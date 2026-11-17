@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Подключение Telegram к Джарвису
set PYTHONUTF8=1
".venv\Scripts\python.exe" setup_telegram.py
