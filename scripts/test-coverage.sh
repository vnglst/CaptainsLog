#!/usr/bin/env bash
set -euo pipefail

# The project deliberately uses its framework-free `run-tests` executable, so
# this works with Apple Command Line Tools and does not require Xcode/XCTest.
coverage_dir=".build/coverage"
merged_profile="$coverage_dir/run-tests.profdata"
mkdir -p "$coverage_dir"
rm -f "$coverage_dir"/*.profraw "$merged_profile" "$coverage_dir/coverage.json"

swift build -Xswiftc -profile-generate -Xswiftc -profile-coverage-mapping --product run-tests
swift build -Xswiftc -profile-generate -Xswiftc -profile-coverage-mapping --product cl
bin_dir="$(swift build --show-bin-path)"
LLVM_PROFILE_FILE="$coverage_dir/run-tests-%p.profraw" "$bin_dir/run-tests"

cli_root="$(mktemp -d "${TMPDIR:-/tmp}/captainslog-cli-tests.XXXXXX")"
trap 'rm -rf "$cli_root"' EXIT
mkdir -p "$cli_root/data/logs"
printf '%s\n' 'A deterministic CLI fixture.' > "$cli_root/input.md"
printf '%s\n' 'A completed log entry.' > "$cli_root/data/logs/2026-07-10-entry.md"

run_cl() {
    CAPTAINS_LOG_CONFIG_PATH="$cli_root/config.json" \
    LLVM_PROFILE_FILE="$coverage_dir/cl-%p.profraw" \
        "$bin_dir/cl" "$@"
}

ping_output="$(run_cl ping)"
case "$ping_output" in
    *"captains log core"*) ;;
    *) printf 'CLI ping returned unexpected output.\n' >&2; exit 1 ;;
esac
run_cl config set dataDir "$cli_root/data" >/dev/null
run_cl config show >/dev/null
run_cl list --data-dir "$cli_root/data" >/dev/null
run_cl resume --data-dir "$cli_root/data" >/dev/null
run_cl cleanup --input "$cli_root/input.md" --print-prompt >/dev/null
run_cl filename --input "$cli_root/input.md" --date 2026-07-10 --print-prompt >/dev/null
run_cl categorize --input "$cli_root/input.md" --output "$cli_root/category.json" --print-prompt >/dev/null
run_cl enrich --input "$cli_root/input.md" --date 2026-07-10 --recording-time 08:30 --print-prompt >/dev/null

xcrun llvm-profdata merge -sparse "$coverage_dir"/*.profraw -o "$merged_profile"
source_files=()
while IFS= read -r source_file; do
    source_files+=("$source_file")
done < <(find Sources/CaptainsLogCore Sources/CaptainsLog Sources/cl Sources/CaptainsLogApp -name '*.swift' -print)

report="$(xcrun llvm-cov report "$bin_dir/run-tests" -object "$bin_dir/cl" -instr-profile="$merged_profile" "${source_files[@]}")"
printf '%s\n' "$report"
xcrun llvm-cov export "$bin_dir/run-tests" -object "$bin_dir/cl" -instr-profile="$merged_profile" "${source_files[@]}" > "$coverage_dir/coverage.json"
line_coverage="$(printf '%s\n' "$report" | awk '/^TOTAL/ { seen = 0; for (i = 1; i <= NF; i++) if ($i ~ /%$/ && ++seen == 3) { sub(/%$/, "", $i); print $i; exit } }')"
minimum_line_coverage=24
awk -v actual="$line_coverage" -v minimum="$minimum_line_coverage" 'BEGIN { exit actual < minimum }' || {
    printf 'Production line coverage %s%% is below the %s%% minimum.\n' "$line_coverage" "$minimum_line_coverage" >&2
    exit 1
}
printf 'Coverage report: %s\n' "$PWD/$coverage_dir/coverage.json"
