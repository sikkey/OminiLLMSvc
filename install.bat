@echo off
setlocal enabledelayedexpansion

set "ROOT_DIR=%~dp0"
set "SOURCE_DIR=%ROOT_DIR%template\config"
set "TARGET_DIR=%ROOT_DIR%apps\config"

if not exist "%SOURCE_DIR%" (
  echo [ERROR] Source template directory not found: %SOURCE_DIR%
  exit /b 1
)

if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

for /r "%SOURCE_DIR%" %%F in (*) do (
  set "REL_PATH=%%~fF"
  set "REL_PATH=!REL_PATH:%SOURCE_DIR%=!"
  set "TARGET_FILE=%TARGET_DIR%!REL_PATH!"
  if not exist "!TARGET_FILE!" (
    if not exist "%%~dpF" mkdir "%%~dpF"
    copy /Y "%%~fF" "!TARGET_FILE!" >nul
    echo [OK] Installed template file: !TARGET_FILE!
  ) else (
    echo [INFO] Already exists, keeping current config: !TARGET_FILE!
  )
)

echo [OK] Template installation complete.
exit /b 0
