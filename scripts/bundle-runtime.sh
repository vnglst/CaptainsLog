#!/bin/bash
# Embed SwiftPM's verified native framework in a release or isolated UI bundle.
set -euo pipefail
PRODUCTS="${1:?usage: bundle-runtime.sh PRODUCTS APP EXECUTABLE...}"
APP="${2:?missing app bundle}"
shift 2
test "$#" -gt 0
if [ ! -d "$PRODUCTS/llama.framework" ]; then
    echo "Error: pinned SwiftPM runtime missing: $PRODUCTS/llama.framework" >&2
    exit 1
fi
mkdir -p "$APP/Contents/Frameworks"
ditto "$PRODUCTS/llama.framework" "$APP/Contents/Frameworks/llama.framework"
for executable in "$@"; do
    # SwiftPM's Xcode build engine adds an absolute PackageFrameworks search path.
    # Remove only generated product paths; unexpected system runtime paths fail checks.
    while IFS= read -r rpath; do
        case "$rpath" in
            "$PRODUCTS"/*) install_name_tool -delete_rpath "$rpath" "$executable" ;;
        esac
    done < <(otool -l "$executable" | awk '/cmd LC_RPATH/ {getline; getline; sub(/^ *path /, ""); sub(/ \(offset.*$/, ""); print}')
    install_name_tool -add_rpath '@executable_path/../Frameworks' "$executable"
done
