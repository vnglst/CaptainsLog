#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fixture="${1:-eval}"
case "$fixture" in
    onboarding|eval|eval-empty|eval-processing|eval-paused|eval-failed|\
    eval-search-results|eval-search-empty|eval-search-error|eval-search-preparing|\
    eval-searching|eval-indexing|eval-model-downloading|eval-model-error|\
    eval-recording|eval-recording-paused) ;;
    *)
        echo "Unknown UI fixture: $fixture" >&2
        exit 2
        ;;
esac

if [ "$(uname -s)" != "Darwin" ]; then
    echo "The native UI check requires macOS. The project uses Apple frameworks; an Xcode IDE is not required." >&2
    exit 2
fi

if [ "${CAPTAINSLOG_UI_SKIP_BUILD:-0}" = "1" ]; then
    bin_dir="$PWD/.build/debug"
else
    swift build --product CaptainsLogApp
    bin_dir="$(swift build --show-bin-path)"
fi
app_root="$(mktemp -d "${TMPDIR:-/tmp}/captainslog-ui-eval.XXXXXX")"
data_dir="$app_root/data"
app_bundle="$app_root/CaptainsLogUITest.app"
bundle_id="local.captainslog.ui-eval.$RANDOM.$$"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources" "$data_dir"

python3 - "$PWD" "$app_root" "$data_dir" <<'PY'
import json
import pathlib
import shutil
import sys

repo, root, data = map(pathlib.Path, sys.argv[1:])

def source(path):
    return (repo / "eval" / path).read_text(encoding="utf-8")

def write(relative, content):
    destination = data / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(content, encoding="utf-8")

def copy(source_path, relative):
    destination = data / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(repo / "eval" / source_path, destination)

def completed(stem, slug, category, transcript_path, cleaned_text, final_body):
    copy(transcript_path, f".pipeline/01-transcribed/{stem}.md")
    write(f".pipeline/02-logs/{stem}.md", cleaned_text)
    write(f".pipeline/03-category/{stem}.json", json.dumps({
        "sourceStem": stem,
        "category": category,
    }))
    write(f".pipeline/04-rename/{stem}.slug.txt", slug)
    write(f".pipeline/04-rename/{slug}.md", cleaned_text)
    write(f"logs/{category.replace('_', '-')}/{slug}.md", final_body)

slug = source("filename/expected/2025-01-14 side project.md").strip().removesuffix(".md")
cleaned = source("cleanup/expected/2025-01-14 side project.md")
completed(
    "2025-01-14-0730", slug, "side_project",
    "transcribe/expected/2025-01-14 side project.md", cleaned,
    source("enrich/expected/2025-01-14 side project.md") + cleaned,
)

work_input = source("enrich/input/01_work_week.md")
completed(
    "2025-01-15-1200", "2025-01-15-work-week-review", "professional",
    "enrich/input/01_work_week.md", work_input,
    source("enrich/expected/01_work_week.md") + work_input,
)

copy("cleanup/input/book-reference.md", ".pipeline/01-transcribed/2025-01-16-0900.md")
(root / "config.json").write_text(json.dumps({
    "schemaVersion": 1,
    "dataDir": str(data),
}), encoding="utf-8")
PY

cp "$bin_dir/CaptainsLogApp" "$app_bundle/Contents/MacOS/CaptainsLogUITest"
cp -R "$bin_dir/CaptainsLog_CaptainsLog.bundle" \
    "$app_bundle/Contents/Resources/CaptainsLog_CaptainsLog.bundle"
cat > "$app_bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CaptainsLogUITest</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleName</key><string>CaptainsLog UI Eval</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
</dict></plist>
PLIST

echo "Isolated UI app: $app_bundle"
echo "Isolated config: $app_root/config.json"
echo "Isolated eval data: $data_dir"
echo "Fixture state: $fixture"
echo "Bundle identifier: $bundle_id"
echo "The app launch skips model download and audio discovery. Do not activate Process pending, retry/resume/reprocess, or recording controls from this fixture UI; those actions use real inference or audio hardware."
if [ "$fixture" = onboarding ]; then
    # Keep first-run completion from changing this user's app-wide preference.
    open --env "CAPTAINSLOG_DEMO_MODE=1" \
        --env "CAPTAINS_LOG_CONFIG_PATH=$app_root/config.json" \
        --env "CAPTAINSLOG_UI_FIXTURE=$fixture" -n "$app_bundle"
else
    open --env "CAPTAINS_LOG_CONFIG_PATH=$app_root/config.json" \
        --env "CAPTAINSLOG_UI_FIXTURE=$fixture" -n "$app_bundle"
fi
