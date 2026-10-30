@echo off
rem One-time setup: installs the two Python packages the importer needs.
cd /d "%~dp0"
where python >nul 2>nul || (echo Python was not found. Install Python 3.10 or newer from https://www.python.org/downloads/windows/ and tick "Add python.exe to PATH". & pause & exit /b 1)
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
echo.
echo Setup finished. Next: run import_drawings.bat (once per drawing set), then run_viewer.bat
pause
