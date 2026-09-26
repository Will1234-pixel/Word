#!/usr/bin/env bash
# Build MATIEC (the IEC 61131-3 compiler used by OpenPLC) into tools/.matiec
# so that plctest.py can compile and test the course's Structured Text files.
#
# Needs: git, a C/C++ compiler, make, autoconf, automake, libtool, flex, bison.
#   Debian/Ubuntu: sudo apt-get install git build-essential autoconf automake libtool flex bison
#   macOS (Homebrew): brew install autoconf automake libtool flex bison
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HERE/.matiec"
# The commit the course was verified against. Newer commits will very likely work too.
REV="3a41303bcb4e50403417bc39c63f88981d7d961e"

if [ -x "$DEST/iec2c" ]; then
  echo "MATIEC already built at $DEST"
  exit 0
fi

if [ ! -d "$DEST/.git" ]; then
  git clone https://github.com/beremiz/matiec.git "$DEST"
fi
cd "$DEST"
git checkout --quiet "$REV" || echo "note: pinned revision not found, building the default branch"
autoreconf -i
./configure
make -j"$( (nproc || sysctl -n hw.ncpu || echo 2) 2>/dev/null | head -1)"
echo
echo "Built $DEST/iec2c"
echo "Try:  python3 $HERE/plctest.py --all \"$HERE/..\""
