#!/bin/bash
# Verify the packaged runtime is self-contained; never repair system linkage.
set -euo pipefail
APP="${1:?usage: check-runtime.sh APP_BUNDLE}"
FRAMEWORK="$APP/Contents/Frameworks/llama.framework"
test -f "$FRAMEWORK/llama"
lipo -verify_arch arm64 "$FRAMEWORK/llama"
load_commands="$(otool -l "$FRAMEWORK/llama")"
awk '$1 == "minos" {split($2, version, "."); found = 1; if (version[1] > 26 || (version[1] == 26 && version[2] > 0)) bad = 1} END {exit bad || !found}' <<< "$load_commands"
symbols="$(nm -gj "$FRAMEWORK/llama")"
for backend in cpu metal; do
    grep -Eq "^_ggml_backend_${backend}_init$" <<< "$symbols"
done
for binary in "$APP/Contents/MacOS/CaptainsLog" "$APP/Contents/MacOS/cl" "$FRAMEWORK/llama"; do
    dependencies="$(otool -L "$binary")"
    if printf '%s\n' "$dependencies" | grep -E '^[[:space:]]' | grep -Ev '^[[:space:]]*(@rpath/llama.framework/Versions/Current/llama|/System/Library/|/usr/lib/)' | grep -q .; then
        echo "Unexpected external runtime dependency in $binary" >&2
        printf '%s\n' "$dependencies" >&2
        exit 1
    fi
    load_commands="$(otool -l "$binary")"
    if grep -Eq '/opt/homebrew|/usr/local|/Cellar/|/\.build/' <<< "$load_commands"; then
        echo "Build-machine path remains in $binary" >&2
        exit 1
    fi
done
for binary in "$APP/Contents/MacOS/CaptainsLog" "$APP/Contents/MacOS/cl"; do
    dependencies="$(otool -L "$binary")"
    load_commands="$(otool -l "$binary")"
    grep -Fq '@rpath/llama.framework/Versions/Current/llama' <<< "$dependencies"
    grep -A5 LC_BUILD_VERSION <<< "$load_commands" | grep -Eq 'minos 26\.0$'
    grep -Fq '@executable_path/../Frameworks' <<< "$load_commands"
done
printf 'Packaged app and CLI use the pinned framework with no build-machine runtime paths.\n'
