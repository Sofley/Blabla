@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Обновление Джарвиса
set PYTHONUTF8=1
echo === Останавливаю Джарвиса...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*start_jarvis.bat*' -or $_.CommandLine -like '*jarvis.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
timeout /t 2 >nul
".venv\Scripts\python.exe" update_jarvis.py
if errorlevel 1 (
  echo !! Не получилось обновить. Проверьте интернет. Запускаю прежнюю версию.
  timeout /t 5 >nul
)
echo === Запускаю Джарвиса...
start "" "%~dp0start_jarvis.bat"
timeout /t 3 >nul
