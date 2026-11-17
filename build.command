#!/bin/bash
# Builds "Robot Companion.app" from main.swift and launches it.
# Збирає програму "Robot Companion.app" з main.swift і запускає її.
cd "$(dirname "$0")" || exit 1

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple Command Line Tools are required. An installer window will open now."
  echo "When it finishes, run this script again."
  echo "Потрібні інструменти розробника Apple (Command Line Tools). Зараз відкриється вікно встановлення."
  echo "Після встановлення запусти цей файл ще раз."
  xcode-select --install
  exit 1
fi

APP="Robot Companion.app"
echo "Building the robot... / Збираю робота..."
mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Robot Companion</string>
  <key>CFBundleDisplayName</key><string>Robot Companion</string>
  <key>CFBundleIdentifier</key><string>local.robotcompanion</string>
  <key>CFBundleExecutable</key><string>Robot</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>5</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>The robot runs your commands: switches tabs in Safari and Chrome and opens apps. / Робот виконує твої команди: перемикає вкладки в Safari та Chrome, відкриває програми.</string>
</dict>
</plist>
PLIST

if swiftc -O main.swift -o "$APP/Contents/MacOS/Robot" -framework AppKit; then
  echo "Done! Launching the robot... / Готово! Запускаю робота..."
  pkill -x Robot 2>/dev/null
  sleep 0.5
  open "$APP"
else
  echo "Build failed. Copy the text above and report it."
  echo "Помилка під час збирання. Скопіюй текст вище і надішли."
fi
