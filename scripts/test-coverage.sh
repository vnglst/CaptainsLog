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
mkdir -p "$cli_root/data/.pipeline/01-transcribed" "$cli_root/empty-data"
cp eval/cleanup/input/captains-log-nlm-llm.md "$cli_root/input.md"
cp eval/transcribe/expected/durins-volk.md "$cli_root/data/.pipeline/01-transcribed/2025-01-14-0830.md"
cp eval/filename/input/01_single_topic.md "$cli_root/filename-input.md"
cp eval/enrich/input/01_work_week.md "$cli_root/enrich-input.md"

run_cl() {
    CAPTAINS_LOG_CONFIG_PATH="$cli_root/config.json" \
    LLVM_PROFILE_FILE="$coverage_dir/cl-%p.profraw" \
        "$bin_dir/cl" "$@"
}

assert_help() {
    local command_name="$1"
    local output
    output="$(run_cl "$command_name" --help)"
    case "$output" in
        *"USAGE:"*"OPTIONS:"*) ;;
        *) printf 'CLI %s help did not include usage and options.\n' "$command_name" >&2; exit 1 ;;
    esac
}

ping_output="$(run_cl ping)"
case "$ping_output" in
    *"captains log core"*) ;;
    *) printf 'CLI ping returned unexpected output.\n' >&2; exit 1 ;;
esac

help_output="$(run_cl --help)"
case "$help_output" in
    *"SUBCOMMANDS:"*"pipeline"*"search"*) ;;
    *) printf 'CLI help omitted expected commands.\n' >&2; exit 1 ;;
esac

# Exercise every leaf command's ArgumentParser help path without invoking
# microphone capture, model downloads, or inference.
for command_name in ping record warm transcribe cleanup categorize filename enrich pipeline resume list search-index search config; do
    assert_help "$command_name"
done
config_set_help="$(run_cl config set --help)"
case "$config_set_help" in
    *"USAGE:"*"<key>"*"<value>"*) ;;
    *) printf 'CLI config set help omitted its key/value arguments.\n' >&2; exit 1 ;;
esac
config_show_help="$(run_cl config show --help)"
case "$config_show_help" in
    *"USAGE:"*) ;;
    *) printf 'CLI config show help omitted usage.\n' >&2; exit 1 ;;
esac

# Required-argument parsing must fail before any command reaches a model or
# hardware dependency. These failures are expected and their diagnostics are
# retained in the isolated temporary directory for inspection on failure.
for command_name in transcribe cleanup categorize filename enrich search; do
    if run_cl "$command_name" >"$cli_root/$command_name-missing-args.txt" 2>&1; then
        printf 'CLI %s accepted missing required arguments.\n' "$command_name" >&2
        exit 1
    fi
    rg --quiet -- 'USAGE:|Missing|missing|requires' "$cli_root/$command_name-missing-args.txt" || {
        printf 'CLI %s rejected missing arguments without parser guidance.\n' "$command_name" >&2
        cat "$cli_root/$command_name-missing-args.txt" >&2
        exit 1
    }
done

for command_name in cleanup filename categorize enrich; do
    output_file="$cli_root/$command_name-missing-file.txt"
    stage_args=(--input "$cli_root/missing-eval-input.md")
    if [[ "$command_name" == categorize ]]; then
        stage_args+=(--output "$cli_root/category.json")
    fi
    if run_cl "$command_name" "${stage_args[@]}" --print-prompt >"$output_file" 2>&1; then
        printf 'CLI %s rendered a prompt for a missing input file.\n' "$command_name" >&2
        exit 1
    fi
    rg --quiet --fixed-strings 'missing-eval-input.md' "$output_file" || {
        printf 'CLI %s failed without identifying the missing input path.\n' "$command_name" >&2
        cat "$output_file" >&2
        exit 1
    }
done

pipeline_error="$cli_root/pipeline-missing-audio.txt"
if run_cl pipeline --input "$cli_root/missing-eval-audio.m4a" --data-dir "$cli_root/pipeline" >"$pipeline_error" 2>&1; then
    printf 'CLI pipeline accepted a missing audio input.\n' >&2
    exit 1
fi
rg --quiet --fixed-strings 'missing-eval-audio.m4a' "$pipeline_error" || {
    printf 'CLI pipeline failed without identifying the missing audio path.\n' >&2
    cat "$pipeline_error" >&2
    exit 1
}
printf 'CLI help, required-argument, and missing-input checks passed.\n'

for duration in 0 -1; do
    for command_name in record pipeline; do
        duration_error="$cli_root/$command_name-duration-$duration.txt"
        duration_args=("--duration=$duration")
        if [[ "$command_name" == record ]]; then
            duration_args+=(--output "$cli_root/should-not-record.m4a")
        else
            duration_args+=(--data-dir "$cli_root/duration-pipeline")
        fi
        if run_cl "$command_name" "${duration_args[@]}" >"$duration_error" 2>&1; then
            printf 'CLI %s accepted non-positive duration %s.\n' "$command_name" "$duration" >&2
            exit 1
        fi
        rg --quiet --fixed-strings -- '--duration must be greater than zero' "$duration_error" || {
            printf 'CLI %s rejected duration %s without its validation error.\n' "$command_name" "$duration" >&2
            cat "$duration_error" >&2
            exit 1
        }
    done
done

stage_error="$cli_root/invalid-resume-stage.txt"
if run_cl resume eval-fixture --data-dir "$cli_root/empty-data" --from-stage unknown >"$stage_error" 2>&1; then
    printf 'CLI resume accepted an unknown --from-stage value.\n' >&2
    exit 1
fi
rg --quiet --fixed-strings -- '--from-stage must be one of' "$stage_error" || {
    printf 'CLI resume rejected an unknown stage without listing valid values.\n' >&2
    cat "$stage_error" >&2
    exit 1
}

run_cl config set dataDir "$cli_root/data" >/dev/null
run_cl config set whisperModel "synthetic/whisper-model" >/dev/null
run_cl config set whisperModelFolder "$cli_root/models/whisper" >/dev/null
run_cl config set qwenModelId "synthetic/eval-model" >/dev/null
run_cl config set qwenModelFolder "$cli_root/models/qwen" >/dev/null
config_output="$(run_cl config show)"
case "$config_output" in
    *"dataDir:             $cli_root/data"*"whisperModel:        synthetic/whisper-model"*"whisperModelFolder:  $cli_root/models/whisper"*"qwenModelId:         synthetic/eval-model"*"qwenModelFolder:     $cli_root/models/qwen"*) ;;
    *) printf 'CLI config show did not return the saved isolated values.\n' >&2; exit 1 ;;
esac
run_cl config set qwenModelFolder unset >/dev/null
unset_config_output="$(run_cl config show)"
case "$unset_config_output" in
    *"qwenModelFolder:     (unset — local GGUF required)"*) ;;
    *) printf 'CLI config set unset did not clear the selected Qwen model folder.\n' >&2; exit 1 ;;
esac

list_data="$cli_root/data"
mkdir -p \
    "$list_data/audio" \
    "$list_data/.pipeline/01-transcribed" \
    "$list_data/.pipeline/02-logs" \
    "$list_data/.pipeline/03-category" \
    "$list_data/.pipeline/04-rename" \
    "$list_data/logs/personal"

# Seed the CLI with synthetic artifacts that represent each pipeline boundary.
printf 'synthetic audio marker' > "$list_data/audio/2025-01-20-0900.m4a"
printf 'synthetic transcript' > "$list_data/.pipeline/01-transcribed/2025-01-13-0900.md"
printf 'synthetic transcript' > "$list_data/.pipeline/01-transcribed/2025-01-12-0900.md"
printf 'synthetic cleaned text' > "$list_data/.pipeline/02-logs/2025-01-12-0900.md"
printf 'synthetic transcript' > "$list_data/.pipeline/01-transcribed/2025-01-11-0900.md"
printf 'synthetic cleaned text' > "$list_data/.pipeline/02-logs/2025-01-11-0900.md"
printf '{"sourceStem":"2025-01-11-0900","category":"personal"}' > "$list_data/.pipeline/03-category/2025-01-11-0900.json"
printf 'synthetic transcript' > "$list_data/.pipeline/01-transcribed/2025-01-10-0900.md"
printf 'synthetic cleaned text' > "$list_data/.pipeline/02-logs/2025-01-10-0900.md"
printf '{"sourceStem":"2025-01-10-0900","category":"personal"}' > "$list_data/.pipeline/03-category/2025-01-10-0900.json"
printf '2025-01-10-enrich-me' > "$list_data/.pipeline/04-rename/2025-01-10-0900.slug.txt"
printf 'synthetic renamed text' > "$list_data/.pipeline/04-rename/2025-01-10-enrich-me.md"
printf 'synthetic transcript' > "$list_data/.pipeline/01-transcribed/2025-01-09-0900.md"
printf 'synthetic cleaned text' > "$list_data/.pipeline/02-logs/2025-01-09-0900.md"
printf '{"sourceStem":"2025-01-09-0900","category":"personal"}' > "$list_data/.pipeline/03-category/2025-01-09-0900.json"
printf '2025-01-09-finished' > "$list_data/.pipeline/04-rename/2025-01-09-0900.slug.txt"
printf 'synthetic renamed text' > "$list_data/.pipeline/04-rename/2025-01-09-finished.md"
printf 'synthetic enriched text' > "$list_data/logs/personal/2025-01-09-finished.md"

list_output="$(run_cl list --data-dir "$list_data")"
assert_list_stage() {
    local expected="$1"
    if ! rg --quiet --fixed-strings -- "$expected" <<< "$list_output"; then
        printf 'CLI list omitted expected stage entry: %s\n' "$expected" >&2
        printf '%s\n' "$list_output" >&2
        exit 1
    fi
}
assert_list_stage "[transcribing]  2025-01-20-0900"
assert_list_stage "[cleaning]  2025-01-14-0830"
assert_list_stage "[categorizing]  2025-01-12-0900"
assert_list_stage "[naming]  2025-01-11-0900"
assert_list_stage "[enriching]  2025-01-10-enrich-me"
assert_list_stage "[done]  2025-01-09-finished"
for stem in \
    2025-01-20-0900 \
    2025-01-14-0830 \
    2025-01-13-0900 \
    2025-01-12-0900 \
    2025-01-11-0900 \
    2025-01-10-0900 \
    2025-01-09-0900; do
    count="$(rg --count --fixed-strings "(stem: $stem)" <<< "$list_output" || true)"
    if [[ "$count" != 1 ]]; then
        printf 'CLI list should show stem %s exactly once; got %s rows.\n' "$stem" "${count:-0}" >&2
        printf '%s\n' "$list_output" >&2
        exit 1
    fi
done
empty_resume_output="$(run_cl resume --data-dir "$cli_root/empty-data")"
case "$empty_resume_output" in
    *"No pending entries to resume."*) ;;
    *) printf 'CLI resume did not report an empty queue.\n' >&2; exit 1 ;;
esac

cleanup_prompt="$(run_cl cleanup --input "$cli_root/input.md" --print-prompt)"
case "$cleanup_prompt" in
    *"<transcript>"*"Obsidian"*) ;;
    *) printf 'Cleanup CLI did not render the transcript prompt.\n' >&2; exit 1 ;;
esac
filename_prompt="$(run_cl filename --input "$cli_root/filename-input.md" --date 2025-01-14 --print-prompt)"
case "$filename_prompt" in
    *"2025-01-14"*"<log_entry>"*) ;;
    *) printf 'Filename CLI did not render the dated log prompt.\n' >&2; exit 1 ;;
esac
for category_input in eval/categorize/input/*.md; do
    category_name="$(basename "$category_input" .md)"
    categorize_prompt="$(run_cl categorize --input "$category_input" --output "$cli_root/$category_name.json" --print-prompt)"
    case "$categorize_prompt" in
        *"- personal:"*"- professional:"*"- side_project:"*"<log_entry>"*) ;;
        *) printf 'Categorize CLI prompt omitted its rubric or fixture text for %s.\n' "$category_name" >&2; exit 1 ;;
    esac
    fixture_text="$(cat "$category_input")"
    case "$categorize_prompt" in
        *"$fixture_text"*) ;;
        *) printf 'Categorize CLI prompt omitted fixture content for %s.\n' "$category_name" >&2; exit 1 ;;
    esac
done
enrich_prompt="$(run_cl enrich --input "$cli_root/enrich-input.md" --date 2025-01-14 --recording-time 08:30 --print-prompt)"
case "$enrich_prompt" in
    *"date: \"2025-01-14\""*"recording_time: \"08:30\""*"<log_entry>"*) ;;
    *) printf 'Enrich CLI did not render supplied metadata in the prompt.\n' >&2; exit 1 ;;
esac

if run_cl search --limit 0 synthetic-query > "$cli_root/invalid-limit.txt" 2>&1; then
    printf 'CLI search accepted a zero result limit.\n' >&2
    exit 1
fi
rg --quiet --fixed-strings -- '--limit must be greater than zero' "$cli_root/invalid-limit.txt" || {
    printf 'CLI search rejected a zero limit without its validation error.\n' >&2
    exit 1
}

if run_cl config set unknown-key value > "$cli_root/invalid-config-key.txt" 2>&1; then
    printf 'CLI config set accepted an unknown key.\n' >&2
    exit 1
fi
rg --quiet --fixed-strings -- 'Unknown key: unknown-key' "$cli_root/invalid-config-key.txt" || {
    printf 'CLI config set rejected an unknown key without a useful error.\n' >&2
    exit 1
}

xcrun llvm-profdata merge -sparse "$coverage_dir"/*.profraw -o "$merged_profile"
source_files=()
while IFS= read -r source_file; do
    source_files+=("$source_file")
done < <(find Sources/CaptainsLogCore Sources/CaptainsLog Sources/cl Sources/CaptainsLogApp -name '*.swift' -print)

report="$(xcrun llvm-cov report "$bin_dir/run-tests" -object "$bin_dir/cl" -instr-profile="$merged_profile" "${source_files[@]}")"
printf '%s\n' "$report"
xcrun llvm-cov export "$bin_dir/run-tests" -object "$bin_dir/cl" -instr-profile="$merged_profile" "${source_files[@]}" > "$coverage_dir/coverage.json"
# Declarative SwiftUI, visual fixtures, and direct hardware/native-inference adapters
# remain in the full report above, but are separate integration gates. The 80% floor
# applies to the remaining production logic, including app state, model orchestration,
# CLI workflows, filesystem handling, search, and pipeline processing.
coverage_excluded_sources=(
    Sources/CaptainsLog/ContentView.swift
    Sources/CaptainsLog/FieldNotesContentView.swift
    Sources/CaptainsLog/FirstRunView.swift
    Sources/CaptainsLog/LCARSKit.swift
    Sources/CaptainsLog/Theme.swift
    Sources/CaptainsLog/FieldNotesTheme.swift
    Sources/CaptainsLog/DesignFixtures.swift
    Sources/CaptainsLogCore/Recorder.swift
    Sources/CaptainsLogCore/Transcriber.swift
    Sources/CaptainsLogCore/LLM.swift
    Sources/CaptainsLogCore/Embeddings.swift
)
testable_sources=()
for source_file in "${source_files[@]}"; do
    excluded=false
    for excluded_source in "${coverage_excluded_sources[@]}"; do
        if [[ "$source_file" == "$excluded_source" ]]; then
            excluded=true
            break
        fi
    done
    if [[ "$excluded" == false ]]; then
        testable_sources+=("$source_file")
    fi
done

testable_report="$(xcrun llvm-cov report "$bin_dir/run-tests" -object "$bin_dir/cl" -instr-profile="$merged_profile" "${testable_sources[@]}")"
printf '\nDeterministic production coverage scope (excluding SwiftUI, fixtures, and native adapters):\n%s\n' "$testable_report"
line_coverage="$(printf '%s\n' "$testable_report" | awk '/^TOTAL/ { seen = 0; for (i = 1; i <= NF; i++) if ($i ~ /%$/ && ++seen == 3) { sub(/%$/, "", $i); print $i; exit } }')"
minimum_line_coverage=80
awk -v actual="$line_coverage" -v minimum="$minimum_line_coverage" 'BEGIN { exit actual < minimum }' || {
    printf 'Deterministic production line coverage %s%% is below the %s%% minimum.\n' "$line_coverage" "$minimum_line_coverage" >&2
    exit 1
}
printf 'Deterministic production line coverage: %s%% (minimum %s%%).\n' "$line_coverage" "$minimum_line_coverage"
printf 'Full production coverage report: %s\n' "$PWD/$coverage_dir/coverage.json"
