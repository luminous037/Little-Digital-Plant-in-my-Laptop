#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
BUILD_ARGS=(-c release --disable-sandbox --cache-path .build/shared-cache --config-path .build/config --security-path .build/security --product LittlePlant)
if [[ "${LITTLE_PLANT_UNIVERSAL:-0}" == "1" ]]; then
    UNIVERSAL_INPUTS=()
    for TARGET_ARCH in arm64 x86_64; do
        swift build "${BUILD_ARGS[@]}" --arch "$TARGET_ARCH"
        TARGET_BIN_DIR=$(swift build "${BUILD_ARGS[@]}" --arch "$TARGET_ARCH" --show-bin-path)
        UNIVERSAL_INPUTS+=("$TARGET_BIN_DIR/LittlePlant")
    done
    BIN_DIR="$PWD/.build/universal-release"
    mkdir -p "$BIN_DIR"
    lipo -create "${UNIVERSAL_INPUTS[@]}" -output "$BIN_DIR/LittlePlant"
else
    swift build "${BUILD_ARGS[@]}"
    BIN_DIR=$(swift build "${BUILD_ARGS[@]}" --show-bin-path)
fi
APP="$PWD/dist/Little Plant.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LittlePlant" "$APP/Contents/MacOS/LittlePlant"
mkdir -p "$APP/Contents/Resources/Fonts"
cp Sources/LittlePlant/Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/"
mkdir -p "$APP/Contents/Resources/Sounds"
cp Sources/LittlePlant/Resources/Sounds/*.wav "$APP/Contents/Resources/Sounds/"
cp Sources/LittlePlant/Resources/Sounds/*.mp3 "$APP/Contents/Resources/Sounds/"
cp Sources/LittlePlant/Resources/Sounds/*.m4a "$APP/Contents/Resources/Sounds/"
# Remove stale tracks from earlier app bundles before copying the current library.
rm -rf "$APP/Contents/Resources/Music"
mkdir -p "$APP/Contents/Resources/Music"
cp Sources/LittlePlant/Resources/Music/*.(mp3|m4a)(N) "$APP/Contents/Resources/Music/"
if [[ -f Sources/LittlePlant/Resources/AppIcon.icns ]]; then
    cp Sources/LittlePlant/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LittlePlant</string>
<key>CFBundleIdentifier</key><string>studio.littleplant.desktop</string>
<key>CFBundleName</key><string>Little Plant</string>
<key>CFBundleDisplayName</key><string>Little Plant</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.2</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSLocationUsageDescription</key><string>현재 위치의 날씨를 식물의 방에 반영합니다. Your location is used to show local weather in your plant room.</string>
<key>NSLocationWhenInUseUsageDescription</key><string>현재 위치의 날씨를 식물의 방에 반영합니다. Your location is used only to fetch local weather.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built: $APP"
