#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LOG_DIR="$ROOT/logs"
SUPPORT_DIR="$HOME/Library/ApplicationSupport/Stock_Update"
UID_VALUE="$(id -u)"
WIDGET_LABEL="com.stockupdate.signal-widget"
WIDGET_PLIST="$LAUNCH_AGENTS/$WIDGET_LABEL.plist"
DAILY_LABEL="com.stockupdate.daily-update"
DAILY_PLIST="$LAUNCH_AGENTS/$DAILY_LABEL.plist"
SUPPORT_APP="$SUPPORT_DIR/StockSignalWidget.app"
SUPPORT_APP_BIN="$SUPPORT_APP/Contents/MacOS/StockSignalWidget"
PYTHON_BIN="$(command -v python3)"

mkdir -p "$LAUNCH_AGENTS" "$LOG_DIR" "$SUPPORT_APP/Contents/MacOS"

chmod +x \
  "$ROOT/scripts/run_desktop_widget.sh" \
  "$ROOT/scripts/update_daily_and_launch_widget.sh" \
  "$ROOT/scripts/launch_desktop_widget.sh" \
  "$ROOT/scripts/stop_desktop_widget.sh"

swiftc "$ROOT/scripts/StockSignalWidget.swift" -o "$SUPPORT_APP_BIN"
cat > "$SUPPORT_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>StockSignalWidget</string>
  <key>CFBundleIdentifier</key>
  <string>local.stock-update.signal-widget</string>
  <key>CFBundleName</key>
  <string>Stock Signal Widget</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

cat > "$WIDGET_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$WIDGET_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SUPPORT_APP_BIN</string>
    <string>$ROOT/data/latest_signal_widget.json</string>
    <string>$ROOT</string>
    <string>$PYTHON_BIN</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/widget.out.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/widget.err.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$UID_VALUE" "$WIDGET_PLIST" >/dev/null 2>&1 || true
launchctl bootout "gui/$UID_VALUE" "$DAILY_PLIST" >/dev/null 2>&1 || true
rm -f "$DAILY_PLIST"
launchctl bootstrap "gui/$UID_VALUE" "$WIDGET_PLIST"
launchctl kickstart -k "gui/$UID_VALUE/$WIDGET_LABEL"

echo "Installed and loaded:"
echo "  $WIDGET_PLIST"
echo "Support app: $SUPPORT_APP"
