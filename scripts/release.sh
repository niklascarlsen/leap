#!/bin/sh
# Publishes a release: runs the tests, builds Leap.app signed with Developer ID, notarizes
# and staples it, uploads Leap-<version>.zip to a GitHub release and updates the Homebrew
# cask in the tap.
#
# Usage: scripts/release.sh <version>      e.g. scripts/release.sh 0.1.0
# Needs a "Developer ID Application" identity in the keychain, a notarytool profile named
# "leap" (xcrun notarytool store-credentials leap ...), gh logged in, and a clone of
# niklascarlsen/homebrew-tap next to this repo (or at TAP_DIR).
set -eu

cd "$(dirname "$0")/.."
VERSION="${1:?usage: scripts/release.sh <version>}"
TAG="v$VERSION"
APP="build/Leap.app"
ZIP="build/Leap-$VERSION.zip"
TAP_DIR="${TAP_DIR:-../homebrew-tap}"

fail() { echo "$1" >&2; exit 1; }
# The version goes into the tag, the zip name, the cask and a sed pattern unescaped.
echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "The version must look like 1.2.3, got '$VERSION'"
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || fail "Releases are made from main"
[ -z "$(git status --porcelain)" ] || fail "The working tree is not clean"
! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || fail "$TAG already exists"
git remote get-url origin >/dev/null 2>&1 || fail "No origin remote to push the tag to"
[ -d "$TAP_DIR/.git" ] || fail "No clone of the Homebrew tap at $TAP_DIR"
[ -z "$(git -C "$TAP_DIR" status --porcelain)" ] || fail "The tap clone is not clean"
git -C "$TAP_DIR" pull --ff-only
# By hash: the name has an "é", which the keychain and the shell may spell differently.
IDENTITY="$(security find-identity -v -p codesigning | awk '/Developer ID Application/ { print $2; exit }')"
[ -n "$IDENTITY" ] || fail "No Developer ID Application identity in the keychain"

swift test
swift format lint --strict --recursive Sources Tests scripts tools Package.swift
LEAP_VERSION="$VERSION" LEAP_IDENTITY="$IDENTITY" scripts/build-app.sh

# notarytool takes a zip; the stapled app is zipped again for the release, so it opens
# without a network check.
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile leap --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"
rm "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA256="$(shasum -a 256 "$ZIP" | awk '{ print $1 }')"

# gh creates and pushes the tag together with the release, so a failed upload leaves no
# tag behind to block the next attempt.
git push origin HEAD
gh release create "$TAG" "$ZIP" --target "$(git rev-parse HEAD)" --title "Leap $VERSION" \
    --generate-notes
git fetch -q origin tag "$TAG"

mkdir -p "$TAP_DIR/Casks"
sed -e "s/@VERSION@/$VERSION/" -e "s/@SHA256@/$SHA256/" packaging/leap.rb > "$TAP_DIR/Casks/leap.rb"
git -C "$TAP_DIR" add Casks/leap.rb
git -C "$TAP_DIR" commit -m "Leap $VERSION"
git -C "$TAP_DIR" push origin HEAD
echo "Released Leap $VERSION: brew install --cask niklascarlsen/tap/leap"
