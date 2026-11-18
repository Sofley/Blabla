@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Джарвис
set PYTHONUTF8=1
rem при запуске тихо подтягиваем исправления с GitHub (без интернета просто пропускаем)
".venv\Scripts\python.exe" update_jarvis.py --auto
:loop
".venv\Scripts\python.exe" jarvis.py
if %errorlevel%==0 exit /b 0
echo Джарвис остановился с ошибкой, перезапуск через 10 секунд...
timeout /t 10 >nul
goto loop
