@echo off
rem Starts the local viewer and opens it in your web browser. Close this window to stop it.
cd /d "%~dp0"
if not exist project\project.json (
  echo No project found. Run import_drawings.bat first.
  pause
  exit /b 1
)
python viewer_server.py --project project
pause
