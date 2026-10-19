#!/bin/sh
# Builds Leap.app, signs it with the first "Apple Development" identity in the
# keychain (a stable identity keeps the Accessibility permission across rebuilds), and
# optionally installs it to ~/Applications.
#
# Usage: scripts/build-app.sh [--install]
# LEAP_VERSION sets the version (default 0.0.0), LEAP_IDENTITY the signing identity
# (scripts/release.sh passes a Developer ID).
set -eu

cd "$(dirname "$0")/.."
VERSION="${LEAP_VERSION:-0.0.0}"
APP="build/Leap.app"

swift build -c release --product Leap
BIN="$(swift build -c release --show-bin-path)/Leap"

# The icon is rendered from its SVG source, only when that changed.
ICON="build/AppIcon.icns"
if [ ! -f "$ICON" ] || [ Resources/AppIcon.svg -nt "$ICON" ] || [ scripts/render-icon.swift -nt "$ICON" ]; then
    mkdir -p build
    swift scripts/render-icon.swift Resources/AppIcon.svg "$ICON"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Leap"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.niklascarlsen.leap</string>
    <key>CFBundleName</key><string>Leap</string>
    <key>CFBundleDisplayName</key><string>Leap</string>
    <key>CFBundleExecutable</key><string>Leap</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>27.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

IDENTITY="${LEAP_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
if [ -z "$IDENTITY" ]; then
    echo "No Apple Development identity found; signing ad hoc (Accessibility must be re-granted after each build)" >&2
    IDENTITY="-"
fi
# Notarization needs a secure timestamp; local builds skip it to stay offline and fast.
# LEAP_IDENTITY may be a name or a certificate hash, so look it up; "-" is ad hoc and
# could otherwise match any identity line with a dash in it.
if [ "$IDENTITY" != "-" ] \
    && security find-identity -v -p codesigning | grep -F -- "$IDENTITY" | grep -q "Developer ID"; then
    TIMESTAMP="--timestamp"
else
    TIMESTAMP="--timestamp=none"
fi
codesign --force --options runtime "$TIMESTAMP" --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP (signed by: $IDENTITY)"

if [ "${1:-}" = "--install" ]; then
    mkdir -p "$HOME/Applications"
    pkill -x Leap 2>/dev/null || true
    rm -rf "$HOME/Applications/Leap.app"
    cp -R "$APP" "$HOME/Applications/Leap.app"
    open "$HOME/Applications/Leap.app"
    echo "Installed and launched ~/Applications/Leap.app"
fi
