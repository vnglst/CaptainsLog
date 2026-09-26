#!/usr/bin/env bash
set -euo pipefail

required=(
    CAPTAINSLOG_WHISPER_MODEL_ID
    CAPTAINSLOG_WHISPER_MODEL_FOLDER
    CAPTAINSLOG_QWEN_MODEL_ID
    CAPTAINSLOG_QWEN_MODEL_FOLDER
)
for name in "${required[@]}"; do
    if [[ -z "${!name:-}" ]]; then
        printf 'Set %s to an already-installed model before running this opt-in smoke.\n' "$name" >&2
        exit 2
    fi
done
[[ -d "$CAPTAINSLOG_WHISPER_MODEL_FOLDER" ]] || {
    printf 'Whisper model folder does not exist: %s\n' "$CAPTAINSLOG_WHISPER_MODEL_FOLDER" >&2
    exit 2
}
[[ -d "$CAPTAINSLOG_QWEN_MODEL_FOLDER" ]] || {
    printf 'Qwen model folder does not exist: %s\n' "$CAPTAINSLOG_QWEN_MODEL_FOLDER" >&2
    exit 2
}
find "$CAPTAINSLOG_QWEN_MODEL_FOLDER" -maxdepth 1 -type f -name '*.gguf' -print -quit | rg --quiet . || {
    printf 'Qwen model folder must contain an installed .gguf file.\n' >&2
    exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$repo_root/eval/transcribe/audio/durins-volk.m4a"
[[ -s "$fixture" ]] || {
    printf 'Synthetic transcription fixture is missing: %s\n' "$fixture" >&2
    exit 2
}
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/captainslog-model-smoke.XXXXXX")"
trap 'rm -rf "$smoke_root"' EXIT
export CAPTAINS_LOG_CONFIG_PATH="$smoke_root/config.json"

cd "$repo_root"
swift run cl config set dataDir "$smoke_root/data" >/dev/null
swift run cl config set whisperModel "$CAPTAINSLOG_WHISPER_MODEL_ID" >/dev/null
swift run cl config set whisperModelFolder "$CAPTAINSLOG_WHISPER_MODEL_FOLDER" >/dev/null
swift run cl config set qwenModelId "$CAPTAINSLOG_QWEN_MODEL_ID" >/dev/null
swift run cl config set qwenModelFolder "$CAPTAINSLOG_QWEN_MODEL_FOLDER" >/dev/null

printf 'Loading and warming the configured Qwen model...\n'
swift run cl warm --model "$CAPTAINSLOG_QWEN_MODEL_ID"

printf 'Transcribing the synthetic eval fixture with the configured Whisper model...\n'
swift run cl transcribe \
    "$fixture" \
    --output "$smoke_root/transcript.md" \
    --model "$CAPTAINSLOG_WHISPER_MODEL_ID" \
    --language nl
test -s "$smoke_root/transcript.md" || {
    printf 'Whisper smoke completed without a non-empty transcript.\n' >&2
    exit 1
}
printf 'Installed-model smoke passed. Models were loaded sequentially; outputs and config were temporary.\n'
