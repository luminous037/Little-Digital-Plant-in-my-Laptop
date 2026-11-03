#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build-app.sh
APP="$PWD/dist/Little Plant.app"
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/little-plant-dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Little Plant.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/Install.txt" <<'INSTALL'
Little Plant

1. Drag Little Plant.app into Applications.
2. Eject this disk image.
3. Open Little Plant from Applications.
4. Click the leaf icon in the menu bar to open your room.

Requires macOS 13 or later.
This development build is ad-hoc signed and is not Apple notarized.
INSTALL
DMG="$PWD/dist/Little-Plant.dmg"
hdiutil create -volname "Little Plant" -srcfolder "$STAGING" -format UDZO -ov "$DMG"
hdiutil verify "$DMG"
(
    cd "$PWD/dist"
    shasum -a 256 Little-Plant.dmg > Little-Plant.dmg.sha256
)
echo "Built: $DMG"
