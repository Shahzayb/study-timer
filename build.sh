#!/bin/sh
# Builds "Study Timer.app", ad-hoc signs it, and installs it to ~/Applications.
set -eu
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/StudyTimer"
APP=".build/Study Timer.app"
DEST="$HOME/Applications/Study Timer.app"

if [ ! -f .build/AppIcon.icns ] || [ make-icon.swift -nt .build/AppIcon.icns ]; then
  rm -rf .build/AppIcon.iconset
  swift make-icon.swift .build/AppIcon.iconset
  iconutil -c icns .build/AppIcon.iconset -o .build/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/StudyTimer"
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.local.StudyTimer</string>
  <key>CFBundleName</key><string>Study Timer</string>
  <key>CFBundleExecutable</key><string>StudyTimer</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"

# A running copy keeps the old binary, so stop it before replacing the bundle.
pkill -x StudyTimer || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$APP" "$DEST"
echo "Installed $DEST"
