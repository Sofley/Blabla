@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Установка Джарвиса
set PYTHONUTF8=1
echo ============================================
echo   Установка голосового помощника Джарвис
echo   Это займёт 10-40 минут. Окно не закрывайте.
echo ============================================
echo.

rem ---------- Python
set "PY="
for %%V in (3.12 3.11) do (
  if not defined PY for /f "delims=" %%i in ('py -%%V -c "import sys;print(sys.executable)" 2^>nul') do set "PY=%%i"
)
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PY (
  echo === Устанавливаю Python 3.11...
  winget install -e --id Python.Python.3.11 --scope user --silent --accept-package-agreements --accept-source-agreements
  set "PY=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
)
if not exist "%PY%" (
  echo.
  echo !! Не удалось установить Python автоматически.
  echo !! Откройте python.org, скачайте Python 3.11, при установке отметьте "Add python.exe to PATH",
  echo !! затем снова запустите install.bat
  start https://www.python.org/downloads/release/python-3119/
  pause
  exit /b 1
)
echo Python: %PY%

rem ---------- Ollama (бесплатный локальный ИИ)
if not exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" (
  echo === Устанавливаю Ollama - локальный ИИ...
  winget install -e --id Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements
)
if not exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" (
  echo !! Ollama не установилась автоматически. Скачайте её с ollama.com, установите и запустите install.bat снова.
  echo !! Без неё Джарвис будет выполнять только простые команды.
  start https://ollama.com/download/windows
)

rem ---------- Библиотеки
echo === Устанавливаю библиотеки Python...
if not exist ".venv\Scripts\python.exe" "%PY%" -m venv .venv
".venv\Scripts\python.exe" -m pip install --upgrade pip --quiet
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 (
  echo !! Ошибка установки библиотек. Проверьте интернет и запустите install.bat ещё раз.
  pause
  exit /b 1
)

rem ---------- Модели, настройки, ярлыки
".venv\Scripts\python.exe" setup_jarvis.py

start "" "%~dp0start_jarvis.bat"
