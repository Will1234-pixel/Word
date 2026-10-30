@echo off
rem Builds the navigation project from the drawings.
rem Usage:  import_drawings.bat  <DXF folder or zip>  [PDF file]
cd /d "%~dp0"
if "%~1"=="" (
  echo Usage: import_drawings.bat "C:\path\to\Drawing_DXF.zip" "C:\path\to\Compined.pdf"
  echo        The PDF is optional. The project is written to the folder "project" next to this file.
  pause
  exit /b 1
)
if "%~2"=="" (
  python import_drawings.py --dxf "%~1" --out project
) else (
  python import_drawings.py --dxf "%~1" --pdf "%~2" --out project
)
pause
