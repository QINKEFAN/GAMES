@echo off
cd /d "%~dp0"
title Q_Game Local Server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
if errorlevel 1 pause
