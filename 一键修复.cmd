@echo off
chcp 65001 >nul
title Limbus 缓存链接 · 守护
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-LimbusCacheLink.ps1"
pause >nul
