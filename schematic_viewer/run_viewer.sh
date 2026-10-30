#!/usr/bin/env sh
# Linux/macOS equivalent of run_viewer.bat
cd "$(dirname "$0")" && python3 viewer_server.py --project "${1:-project}"
