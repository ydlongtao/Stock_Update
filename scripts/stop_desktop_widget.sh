#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BIN="$ROOT/build/StockSignalWidget.app/Contents/MacOS/StockSignalWidget"

if pgrep -f "$APP_BIN" >/dev/null 2>&1; then
  pkill -f "$APP_BIN"
  echo "Desktop widget stopped."
else
  echo "Desktop widget is not running."
fi
