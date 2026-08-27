@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%llm-coder-proxy.test.ps1"
exit /b %ERRORLEVEL%
