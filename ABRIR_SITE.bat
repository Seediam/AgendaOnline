@echo off
title Nosso Tempo
cd /d "%~dp0"
start "" http://localhost:8080
python -m http.server 8080
if errorlevel 1 (
  echo.
  echo Nao consegui iniciar pelo Python.
  echo Voce ainda pode abrir o arquivo index.html diretamente.
  pause
)
