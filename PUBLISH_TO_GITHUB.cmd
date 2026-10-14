@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PUBLISH_TO_GITHUB.ps1"
if errorlevel 1 (
  echo.
  echo Upload did not complete. Please capture the error shown above.
) else (
  echo.
  echo Upload script finished successfully.
)
echo.
pause
