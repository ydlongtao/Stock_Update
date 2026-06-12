#!/usr/bin/env bash
set -euo pipefail

UID_VALUE="$(id -u)"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
SUPPORT_DIR="$HOME/Library/ApplicationSupport/Stock_Update"
LEGACY_SUPPORT_DIR="$HOME/Library/Application Support/Stock_Update"
WIDGET_PLIST="$LAUNCH_AGENTS/com.stockupdate.signal-widget.plist"
DAILY_PLIST="$LAUNCH_AGENTS/com.stockupdate.daily-update.plist"

launchctl bootout "gui/$UID_VALUE" "$WIDGET_PLIST" >/dev/null 2>&1 || true
launchctl bootout "gui/$UID_VALUE" "$DAILY_PLIST" >/dev/null 2>&1 || true
rm -f "$WIDGET_PLIST" "$DAILY_PLIST"
pkill -f "$SUPPORT_DIR/StockSignalWidget.app/Contents/MacOS/StockSignalWidget" >/dev/null 2>&1 || true
pkill -f "$LEGACY_SUPPORT_DIR/StockSignalWidget.app/Contents/MacOS/StockSignalWidget" >/dev/null 2>&1 || true

echo "LaunchAgents removed."
