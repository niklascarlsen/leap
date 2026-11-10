#!/bin/sh
# Builds Leap.app, signs it with the keychain's "Developer ID Application" identity, or
# else an "Apple Development" one, and optionally installs it to ~/Applications.
# Developer ID is preferred because the Accessibility grant is tied to the signature:
# local builds then share one grant with releases and keep it across rebuilds.
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

# By certificate hash: `security` escapes non-ASCII characters in the names.
find_identity() {
    security find-identity -v -p codesigning | awk -v kind="$1" '$0 ~ kind { print $2; exit }'
}
IDENTITY="${LEAP_IDENTITY:-$(find_identity "Developer ID Application")}"
IDENTITY="${IDENTITY:-$(find_identity "Apple Development")}"
if [ -z "$IDENTITY" ]; then
    echo "No signing identity found; signing ad hoc (Accessibility must be re-granted after each build)" >&2
    IDENTITY="-"
fi
# Notarization (releases, which pass LEAP_IDENTITY) needs a secure timestamp; local
# builds skip it to stay offline and fast.
if [ -n "${LEAP_IDENTITY:-}" ]; then
    TIMESTAMP="--timestamp"
else
    TIMESTAMP="--timestamp=none"
fi
codesign --force --options runtime "$TIMESTAMP" --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP (signed by: $IDENTITY)"

if [ "${1:-}" = "--install" ]; then
    # Two copies would fight over the shortcuts and the Accessibility grant.
    if [ -d /Applications/Leap.app ]; then
        echo "Another Leap is installed in /Applications; remove it first (brew uninstall --cask leap)" >&2
        exit 1
    fi
    mkdir -p "$HOME/Applications"
    # Leap quits on SIGTERM as from its menu; wait so that open launches the new build.
    pkill -x Leap 2>/dev/null || true
    while pgrep -x Leap >/dev/null; do sleep 0.1; done
    rm -rf "$HOME/Applications/Leap.app"
    cp -R "$APP" "$HOME/Applications/Leap.app"
    open "$HOME/Applications/Leap.app"
    echo "Installed and launched ~/Applications/Leap.app"
fi
