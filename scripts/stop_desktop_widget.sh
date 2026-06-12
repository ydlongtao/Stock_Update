#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BIN="$ROOT/build/StockSignalWidget.app/Contents/MacOS/StockSignalWidget"
SUPPORT_APP_BIN="$HOME/Library/Application Support/Stock_Update/StockSignalWidget.app/Contents/MacOS/StockSignalWidget"
SUPPORT_APP_BIN_NO_SPACE="$HOME/Library/ApplicationSupport/Stock_Update/StockSignalWidget.app/Contents/MacOS/StockSignalWidget"
UID_VALUE="$(id -u)"
WIDGET_PLIST="$HOME/Library/LaunchAgents/com.stockupdate.signal-widget.plist"
STOPPED=0

if [[ -f "$WIDGET_PLIST" ]]; then
  launchctl bootout "gui/$UID_VALUE" "$WIDGET_PLIST" >/dev/null 2>&1 || true
fi

if pgrep -f "$APP_BIN" >/dev/null 2>&1; then
  pkill -f "$APP_BIN"
  STOPPED=1
fi

if pgrep -f "$SUPPORT_APP_BIN" >/dev/null 2>&1; then
  pkill -f "$SUPPORT_APP_BIN"
  STOPPED=1
fi

if pgrep -f "$SUPPORT_APP_BIN_NO_SPACE" >/dev/null 2>&1; then
  pkill -f "$SUPPORT_APP_BIN_NO_SPACE"
  STOPPED=1
fi

if pgrep -f "StockSignalWidget.app/Contents/MacOS/StockSignalWidget" >/dev/null 2>&1; then
  pkill -f "StockSignalWidget.app/Contents/MacOS/StockSignalWidget"
  STOPPED=1
fi

if [[ "$STOPPED" == "1" ]]; then
  echo "Desktop widget stopped."
else
  echo "Desktop widget is not running."
fi
