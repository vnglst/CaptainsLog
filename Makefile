.DEFAULT_GOAL := run
# Evaluations share on-device model memory. Keep multi-target invocations sequential.
.NOTPARALLEL:

SWIFT ?= swift
CONFIGURATION ?= debug
ARGS ?=
MODE ?=
STAGE ?=
CASE ?=
BUMP ?= auto
VERSION ?=
BASE ?=
HEAD ?= HEAD
RUN_DIR ?=
COMPARISON_RUN ?=
PORT ?=
SHA256 ?=

# Directory timestamps also invalidate the app when source files are added or removed.
DEV_INPUTS := Package.swift Package.resolved $(shell find Sources Vendor Packages/FixtureLibrary Resources -name .build -prune -o -name .swiftpm -prune -o -type f -print -o -type d -print)

.PHONY: help build dev run website cli tests tests-unit tests-coverage tests-updates tests-release tests-evals tests-runtime tests-enrich tests-model tests-recorder tests-app-performance tests-search-shutdown ui evals evals-review evals-list evals-pipeline evals-suites packaging release release-notes release-check release-cask icons clean

help:
	@printf '%s\n' \
	  'make dev (or make / make run)  Incrementally build and start the development app' \
	  'make website                  Serve the landing page locally (PORT=8765)' \
	  'make build                    Build app, CLI and test executables' \
	  'make tests                    Run deterministic tests in isolated storage' \
	  'make evals                    Run all fixture evaluations sequentially' \
	  'make evals-review              Resume the latest transcript review in your browser' \
	  'make packaging                Build the release app, CLI and ZIP' \
	  'make release                  Prepare a release on clean main' \
	  '' \
	  'Options: CONFIGURATION=debug|release, ARGS="..."' \
	  'Evals: MODE=all|pipeline|suites, STAGE=filename, CASE="fixture stem"' \
	  'Release: BUMP=auto|patch|minor|major|version, ARGS=--dry-run|--publish' \
	  '' \
	  'Iteration: cli, tests-unit, tests-coverage, tests-updates, tests-release,' \
	  'tests-evals, tests-runtime, tests-enrich, tests-model, tests-recorder, tests-app-performance, tests-search-shutdown, ui, evals-list,' \
	  'evals-pipeline, evals-suites, release-notes, release-check, release-cask,' \
	  'icons, clean. See scripts/README.md for options and safety limits.'

build:
	$(SWIFT) build -c "$(CONFIGURATION)" $(ARGS)

run: dev

dev: .build/debug/CaptainsLogApp
	.build/debug/CaptainsLogApp $(ARGS)

website:
	$(SWIFT) run --package-path scripts captainslog-tools website "$(or $(PORT),8765)"

.build/debug/CaptainsLogApp: $(DEV_INPUTS)
	$(SWIFT) build -c debug --product CaptainsLogApp

cli:
	$(SWIFT) run -c "$(CONFIGURATION)" cl $(ARGS)

tests:
	$(SWIFT) scripts/tooling.swift isolated-check $(SWIFT) run -c "$(CONFIGURATION)" run-tests $(ARGS)

tests-unit:
	$(SWIFT) scripts/tooling.swift isolated-check $(SWIFT) run -c "$(CONFIGURATION)" run-tests --unit $(ARGS)

tests-coverage:
	$(SWIFT) scripts/tooling.swift isolated-check $(SWIFT) scripts/tooling.swift test-coverage $(ARGS)

tests-updates:
	$(SWIFT) scripts/tooling.swift isolated-check $(SWIFT) scripts/tooling.swift test-updates $(ARGS)

tests-release:
	$(SWIFT) scripts/tooling.swift test-release-tooling $(ARGS)

tests-evals:
	$(SWIFT) scripts/tooling.swift test-evals $(ARGS)

tests-runtime:
	$(SWIFT) scripts/tooling.swift test-runtime

tests-enrich:
	$(MAKE) build CONFIGURATION=debug
	$(SWIFT) scripts/tooling.swift isolated-check $(SWIFT) scripts/tooling.swift test-enrich-eval $(ARGS)

tests-model:
	$(SWIFT) scripts/tooling.swift isolated-check $(SWIFT) scripts/tooling.swift test-model-smoke $(ARGS)

tests-app-performance:
	@test -n "$(RUN_DIR)"
	$(SWIFT) build -c debug
	$(SWIFT) scripts/test-app-performance.swift "$$($(SWIFT) build -c debug --show-bin-path)/CaptainsLogApp" "$(RUN_DIR)" $(ARGS)

tests-search-shutdown:
	@test -n "$(RUN_DIR)"
	$(SWIFT) build -c debug
	$(SWIFT) scripts/test-search-shutdown.swift "$$($(SWIFT) build -c debug --show-bin-path)/CaptainsLogApp" "$(RUN_DIR)" $(ARGS)

tests-recorder:
	$(SWIFT) scripts/tooling.swift isolated-check $(SWIFT) scripts/tooling.swift test-recorder-hardware $(ARGS)

ui:
	$(SWIFT) scripts/tooling.swift test-ui $(if $(ARGS),$(ARGS),eval)

evals:
	$(SWIFT) scripts/tooling.swift evals $(if $(STAGE),--stage "$(STAGE)",$(if $(MODE),--$(MODE))) $(if $(CASE),--case "$(CASE)") $(ARGS)

evals-review:
	$(SWIFT) scripts/tooling.swift evals-review $(if $(RUN_DIR),--run "$(RUN_DIR)") $(if $(COMPARISON_RUN),--comparison-run "$(COMPARISON_RUN)") $(if $(PORT),--port "$(PORT)") $(ARGS)

evals-list:
	$(SWIFT) scripts/tooling.swift evals --list $(if $(STAGE),--stage "$(STAGE)",$(if $(MODE),--$(MODE))) $(if $(CASE),--case "$(CASE)") $(ARGS)

evals-pipeline:
	$(MAKE) evals MODE=pipeline

evals-suites:
	$(MAKE) evals MODE=suites

packaging:
	$(SWIFT) scripts/tooling.swift build-app $(ARGS)

release:
	$(SWIFT) scripts/release.swift "$(BUMP)" $(ARGS)

release-notes:
	$(SWIFT) scripts/release.swift notes "$(VERSION)"

release-check:
	$(SWIFT) scripts/release.swift check "$(BASE)" "$(HEAD)"

release-cask:
	$(SWIFT) scripts/release.swift cask "$(VERSION)" "$(SHA256)"

icons:
	$(SWIFT) scripts/tooling.swift make-iconset $(ARGS)

clean:
	$(SWIFT) package clean
