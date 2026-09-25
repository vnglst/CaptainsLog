#!/bin/bash
# Build a self-signed app bundle containing both the GUI and `cl` CLI.
#
# Requires an Apple Silicon build Mac, Swift 6.2+, and Homebrew llama.cpp.
# Produces dist/CaptainsLog.app and a versioned ZIP suitable for a Homebrew cask.

set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="nl.koenvangilst.CaptainsLog"
APP_NAME="CaptainsLog"
VERSION="$(tr -d '[:space:]' < VERSION)"
DIST="dist"
APP="$DIST/$APP_NAME.app"
ZIP="$DIST/$APP_NAME-$VERSION.zip"
PRODUCTS="$(swift build -c release --show-bin-path)"

if [ "$(uname -m)" != "arm64" ]; then
    echo "Error: CaptainsLog release builds require an Apple Silicon Mac." >&2
    exit 1
fi

echo "==> Building release app and CLI ($VERSION)..."
swift build -c release --product "${APP_NAME}App"
swift build -c release --product cl

APP_BIN="$PRODUCTS/${APP_NAME}App"
CLI_BIN="$PRODUCTS/cl"
RESOURCE_BUNDLE="$PRODUCTS/CaptainsLog_CaptainsLog.bundle"

for required in "$APP_BIN" "$CLI_BIN" "$RESOURCE_BUNDLE"; do
    if [ ! -e "$required" ]; then
        echo "Error: expected build output at $required" >&2
        exit 1
    fi
done

echo "==> Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$APP_BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$CLI_BIN" "$APP/Contents/MacOS/cl"
ditto "$RESOURCE_BUNDLE" "$APP/Contents/Resources/CaptainsLog_CaptainsLog.bundle"

echo "==> Bundling llama.cpp runtime libraries..."
LLAMA_PREFIX="$(brew --prefix llama.cpp)"
GGML_PREFIX="$(brew --prefix ggml)"
OMP_PREFIX="$(brew --prefix libomp)"
LLAMA_LIB="$LLAMA_PREFIX/lib/libllama.0.dylib"
GGML_LIB="$GGML_PREFIX/lib/libggml.0.dylib"
GGML_BASE_LIB="$GGML_PREFIX/lib/libggml-base.0.dylib"
OMP_LIB="$OMP_PREFIX/lib/libomp.dylib"

for lib in "$LLAMA_LIB" "$GGML_LIB" "$GGML_BASE_LIB" "$OMP_LIB"; do
    if [ ! -f "$lib" ]; then
        echo "Error: required runtime library not found: $lib" >&2
        echo "Install build dependencies with: brew install llama.cpp libomp" >&2
        exit 1
    fi
    cp "$lib" "$APP/Contents/Frameworks/"
done
chmod u+w "$APP/Contents/Frameworks/"*.dylib

APP_EXECUTABLE="$APP/Contents/MacOS/$APP_NAME"
CLI_EXECUTABLE="$APP/Contents/MacOS/cl"
LLAMA_DST="$APP/Contents/Frameworks/libllama.0.dylib"
GGML_DST="$APP/Contents/Frameworks/libggml.0.dylib"
GGML_BASE_DST="$APP/Contents/Frameworks/libggml-base.0.dylib"
OMP_DST="$APP/Contents/Frameworks/libomp.dylib"

for executable in "$APP_EXECUTABLE" "$CLI_EXECUTABLE"; do
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$executable" 2>/dev/null || true
    install_name_tool -change "$LLAMA_LIB" "@rpath/libllama.0.dylib" "$executable"
    install_name_tool -change "$GGML_LIB" "@rpath/libggml.0.dylib" "$executable"
    install_name_tool -change "$GGML_BASE_LIB" "@rpath/libggml-base.0.dylib" "$executable"
done

install_name_tool -id "@rpath/libllama.0.dylib" "$LLAMA_DST"
install_name_tool -id "@rpath/libggml.0.dylib" "$GGML_DST"
install_name_tool -id "@rpath/libggml-base.0.dylib" "$GGML_BASE_DST"
install_name_tool -id "@rpath/libomp.dylib" "$OMP_DST"
install_name_tool -change "$GGML_LIB" "@rpath/libggml.0.dylib" "$LLAMA_DST"
install_name_tool -change "$GGML_BASE_LIB" "@rpath/libggml-base.0.dylib" "$LLAMA_DST"
install_name_tool -change "$GGML_BASE_LIB" "@rpath/libggml-base.0.dylib" "$GGML_DST" 2>/dev/null || true
install_name_tool -change "$OMP_LIB" "@rpath/libomp.dylib" "$GGML_BASE_DST"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
    echo "Warning: Resources/AppIcon.icns not found. Run scripts/make-iconset.sh to generate."
fi

if [ -d "prompts" ]; then
    ditto "prompts" "$APP/Contents/Resources/prompts"
fi

THIRD_PARTY_DIR="$APP/Contents/Resources/ThirdPartyLicenses"
mkdir -p "$THIRD_PARTY_DIR/sqlite-vec" "$THIRD_PARTY_DIR/Antonio" \
    "$THIRD_PARTY_DIR/llama.cpp" "$THIRD_PARTY_DIR/LLVM-OpenMP"
cp THIRD-PARTY-NOTICES.md "$APP/Contents/Resources/"
cp Sources/CSQLiteVec/LICENSE-MIT "$THIRD_PARTY_DIR/sqlite-vec/"
cp Sources/CSQLiteVec/LICENSE-APACHE "$THIRD_PARTY_DIR/sqlite-vec/"
cp Sources/CaptainsLog/Resources/ThirdPartyLicenses/Antonio-OFL-1.1.txt "$THIRD_PARTY_DIR/Antonio/"

for checkout in .build/checkouts/*; do
    [ -d "$checkout" ] || continue
    package_name="$(basename "$checkout")"
    package_license_dir="$THIRD_PARTY_DIR/SwiftPackages/$package_name"
    while IFS= read -r -d '' license_file; do
        relative_path="${license_file#"$checkout"/}"
        destination="$package_license_dir/$relative_path"
        mkdir -p "$(dirname "$destination")"
        cp "$license_file" "$destination"
    done < <(find "$checkout" -type f \
        \( -iname 'LICENSE' -o -iname 'LICENSE.*' -o -iname 'NOTICE' \
        -o -iname 'NOTICE.*' -o -iname 'COPYING*' \) -print0)
done

cp "$LLAMA_PREFIX/LICENSE" "$THIRD_PARTY_DIR/llama.cpp/"
cp "$OMP_PREFIX/LICENSE.TXT" "$THIRD_PARTY_DIR/LLVM-OpenMP/"

GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Captain's Log</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>GitCommitHash</key>
    <string>$GIT_COMMIT</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Captain's Log records voice memos from your selected microphone. Audio is processed on-device and never leaves your Mac.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Koen van Gilst</string>
</dict>
</plist>
PLIST

echo "==> Applying ad-hoc signatures..."
chmod -R u+w "$APP/Contents/Resources/ThirdPartyLicenses"
xattr -cr "$APP"
codesign --force --sign - "$APP/Contents/Frameworks/"*.dylib
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$CLI_EXECUTABLE"

echo "==> Creating versioned Homebrew archive..."
mkdir -p "$DIST"
TEMP_ZIP="$ZIP.tmp"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$TEMP_ZIP"
mv -f "$TEMP_ZIP" "$ZIP"

echo "App: $APP"
echo "Archive: $ZIP"
shasum -a 256 "$ZIP"
