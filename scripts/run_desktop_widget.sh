#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/StockSignalWidget.app"
APP_BIN="$APP/Contents/MacOS/StockSignalWidget"
SOURCE="$ROOT/scripts/StockSignalWidget.swift"
WIDGET_JSON="$ROOT/data/latest_signal_widget.json"

mkdir -p "$APP/Contents/MacOS"

if [[ ! -x "$APP_BIN" || "$SOURCE" -nt "$APP_BIN" ]]; then
  swiftc "$SOURCE" -o "$APP_BIN"
  cat > "$APP/Contents/Info.plist" <<PLIST
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
fi

if [[ ! -f "$WIDGET_JSON" ]]; then
  python3 "$ROOT/scripts/generate_report.py"
fi

exec "$APP_BIN" "$WIDGET_JSON" "$ROOT" "$(command -v python3)"
