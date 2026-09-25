#!/bin/bash
# Generate Resources/AppIcon.icns from scripts/make-icon.swift.
# Run after editing the icon design. Output is committed to the repo.

set -euo pipefail

cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

ICONSET="$TMP/AppIcon.iconset"
SRC="$TMP/icon-1024.png"
OUT="Resources/AppIcon.icns"

mkdir -p "$ICONSET" Resources

swift scripts/make-icon.swift "$SRC"

# macOS expects both @1x and @2x at each size.
sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png"       >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png"    >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png"       >/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png"    >/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png"     >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png"  >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png"     >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png"  >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png"     >/dev/null
cp "$SRC" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$OUT"

echo "Wrote $OUT ($(du -h "$OUT" | cut -f1))"
