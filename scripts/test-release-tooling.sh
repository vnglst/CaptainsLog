#!/usr/bin/env bash
# Synthetic release fixtures only; no inference or network publication.
set -euo pipefail
cd "$(dirname "$0")/.."
release_test_root="$(mktemp -d "${TMPDIR:-/tmp}/captainslog-release-tests.XXXXXX")"
trap 'rm -rf "$release_test_root"' EXIT
swiftc scripts/release.swift -o "$release_test_root/release-tool"
release_tool="$release_test_root/release-tool"
"$release_tool" test

git init -q --bare "$release_test_root/origin.git"
mkdir "$release_test_root/source" "$release_test_root/bin"
cd "$release_test_root/source"
git init -q -b main
git config user.name 'Release fixture'
git config user.email 'fixture@example.invalid'
git config commit.gpgsign false
git config tag.gpgsign false
mkdir Casks
printf '0.1.2\n' > VERSION
cat > CHANGELOG.md <<'CHANGELOG'
# Changelog

## [Unreleased]

- Synthetic release fix.

## [0.1.2] - 2026-10-01

- Previous synthetic feature.

[Unreleased]: https://github.com/vnglst/CaptainsLog/compare/v0.1.2...HEAD
CHANGELOG
printf '  version "0.1.2"\n  sha256 "%064d"\n' 0 > Casks/captainslog.rb
commit_fixture() { git add .; git commit --allow-empty -qm "${1:-chore(test): synthetic fixture change}"; }
expect_failure() {
    if "$@" > "$release_test_root/failure.log" 2>&1; then
        echo "Expected failure: $*" >&2
        exit 1
    fi
}
commit_fixture
release_base="$(git rev-parse HEAD)"
git tag v0.1.2
"$release_tool" --dry-run > "$release_test_root/no-release.log"
[[ "$(cat "$release_test_root/no-release.log")" == *"no releasable changes"* ]]
commit_fixture 'fix(test): repair synthetic fixture'
"$release_tool" --dry-run > "$release_test_root/auto-preview.md"
[[ "$(cat "$release_test_root/auto-preview.md")" == *"## [0.1.3]"* ]]
commit_fixture $'chore(test): change synthetic config\n\nBREAKING CHANGE: remove old fixture key'
"$release_tool" --dry-run > "$release_test_root/breaking-preview.md"
[[ "$(cat "$release_test_root/breaking-preview.md")" == *"## [0.2.0]"* ]]
commit_fixture 'feat(test): add synthetic capability'
"$release_tool" auto --dry-run > "$release_test_root/auto-preview.md"
[[ "$(cat "$release_test_root/auto-preview.md")" == *"## [0.2.0]"* ]]
git tag v9.0.0
expect_failure "$release_tool" --dry-run
git tag -d v9.0.0 > /dev/null
release_base="$(git rev-parse HEAD)"
git remote add origin "$release_test_root/origin.git"
git push -q origin main
"$release_tool" patch --dry-run > "$release_test_root/preview.md"
test "$(git rev-parse HEAD)" = "$release_base"
test -z "$(git status --porcelain)"
test "$(git tag --list)" = v0.1.2
[[ "$(cat "$release_test_root/preview.md")" == *"## [0.1.3]"* ]]

printf 'Uncommitted synthetic documentation\n' > README.md
expect_failure "$release_tool" patch
commit_fixture
expect_failure "$release_tool" check "$release_base" HEAD
printf '\n' >> CHANGELOG.md
commit_fixture
"$release_tool" check "$release_base" HEAD
"$release_tool" check 0000000000000000000000000000000000000000 HEAD
"$release_tool" check HEAD HEAD
git switch -qc fixture-branch
expect_failure "$release_tool" patch
git switch -q main
git tag v0.1.3
expect_failure "$release_tool" patch
git tag -d v0.1.3 > /dev/null

# Substitute only the expensive check executables; Git is real and the remote
# is a local bare fixture. No skip-checks option is exposed by the release tool.
cat > "$release_test_root/bin/check" <<'CHECK'
#!/bin/sh
set -eu
: "${CAPTAINS_LOG_CONFIG_PATH:?Missing isolated config}"
: "${CAPTAINS_LOG_DATA_DIR:?Missing isolated data}"
printf '%s %s\n' "$(basename "$0")" "$*" >> "$RELEASE_FIXTURE_CHECK_LOG"
test "${RELEASE_FIXTURE_FAIL:-0}" = 0
CHECK
chmod +x "$release_test_root/bin/check"
ln -s check "$release_test_root/bin/swift"
ln -s check "$release_test_root/bin/bash"
export PATH="$release_test_root/bin:$PATH"
export RELEASE_FIXTURE_CHECK_LOG="$release_test_root/checks.log"
release_before="$(git rev-parse HEAD)"
export RELEASE_FIXTURE_FAIL=1
expect_failure "$release_tool" patch
test "$(git rev-parse HEAD)" = "$release_before"
test "$(git tag --list)" = v0.1.2
test -z "$(git status --porcelain)"
unset RELEASE_FIXTURE_FAIL
: > "$RELEASE_FIXTURE_CHECK_LOG"
"$release_tool" --publish > "$release_test_root/publish.log"
test "$(cat VERSION)" = 0.2.0
test -z "$(git status --porcelain)"
test "$(git rev-parse 'v0.2.0^{}')" = "$(git rev-parse HEAD)"
test "$(git rev-parse origin/main)" = "$(git rev-parse HEAD)"
[[ "$(git ls-remote origin refs/tags/v0.2.0)" == *refs/tags/v0.2.0* ]]
"$release_tool" check "$release_before" HEAD
test "$(git log -1 --format=%s)" = 'chore(release): CaptainsLog 0.2.0'
"$release_tool" --dry-run > "$release_test_root/post-release.log"
[[ "$(cat "$release_test_root/post-release.log")" == *"no releasable changes"* ]]
cat > "$release_test_root/expected-checks.log" <<'CHECKS'
bash scripts/test-release-tooling.sh
swift build
swift run run-tests
bash scripts/run-evals.sh --all
CHECKS
diff -u "$release_test_root/expected-checks.log" "$RELEASE_FIXTURE_CHECK_LOG"

release_before="$(git rev-parse HEAD)"
"$release_tool" cask 0.2.0 "$(printf '%064d' 1)"
commit_fixture
"$release_tool" check "$release_before" HEAD
"$release_tool" --dry-run > "$release_test_root/maintenance-preview.log"
[[ "$(cat "$release_test_root/maintenance-preview.log")" == *"no releasable changes"* ]]
release_before="$(git rev-parse HEAD)"
printf '# Manual cask change\n' >> Casks/captainslog.rb
commit_fixture
expect_failure "$release_tool" check "$release_before" HEAD
echo 'Release Git/CLI fixtures passed (checks mocked; local atomic publication verified).'
