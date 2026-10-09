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
SHA256 ?=

.PHONY: help build run cli tests tests-unit tests-coverage tests-updates tests-release tests-evals tests-runtime tests-enrich tests-model tests-recorder ui evals evals-list evals-pipeline evals-suites packaging release release-notes release-check release-cask icons clean

help:
	@printf '%s\n' \
	  'make (or make run)             Start the development app' \
	  'make build                    Build app, CLI and test executables' \
	  'make tests                    Run deterministic tests in isolated storage' \
	  'make evals                    Run all fixture evaluations sequentially' \
	  'make packaging                Build the release app, CLI and ZIP' \
	  'make release                  Prepare a release on clean main' \
	  '' \
	  'Options: CONFIGURATION=debug|release, ARGS="..."' \
	  'Evals: MODE=all|pipeline|suites, STAGE=filename, CASE="fixture stem"' \
	  'Release: BUMP=auto|patch|minor|major|version, ARGS=--dry-run|--publish' \
	  '' \
	  'Iteration: cli, tests-unit, tests-coverage, tests-updates, tests-release,' \
	  'tests-evals, tests-runtime, tests-enrich, tests-model, tests-recorder, ui, evals-list,' \
	  'evals-pipeline, evals-suites, release-notes, release-check, release-cask,' \
	  'icons, clean. See scripts/README.md for options and safety limits.'

build:
	$(SWIFT) build -c "$(CONFIGURATION)" $(ARGS)

run:
	$(SWIFT) run -c debug CaptainsLogApp $(ARGS)

cli:
	$(SWIFT) run -c "$(CONFIGURATION)" cl $(ARGS)

tests:
	$(SWIFT) scripts/isolated-check.swift $(SWIFT) run -c "$(CONFIGURATION)" run-tests $(ARGS)

tests-unit:
	$(SWIFT) scripts/isolated-check.swift $(SWIFT) run -c "$(CONFIGURATION)" run-tests --unit $(ARGS)

tests-coverage:
	$(SWIFT) scripts/isolated-check.swift $(SWIFT) scripts/test-coverage.swift $(ARGS)

tests-updates:
	$(SWIFT) scripts/isolated-check.swift $(SWIFT) scripts/test-updates.swift $(ARGS)

tests-release:
	$(SWIFT) scripts/test-release-tooling.swift $(ARGS)

tests-evals:
	$(SWIFT) scripts/test-evals.swift $(ARGS)

tests-runtime:
	$(SWIFT) scripts/test-runtime.swift

tests-enrich:
	$(MAKE) build CONFIGURATION=debug
	$(SWIFT) scripts/isolated-check.swift $(SWIFT) scripts/test-enrich-eval.swift $(ARGS)

tests-model:
	$(SWIFT) scripts/isolated-check.swift $(SWIFT) scripts/test-model-smoke.swift $(ARGS)

tests-recorder:
	$(SWIFT) scripts/isolated-check.swift $(SWIFT) scripts/test-recorder-hardware.swift $(ARGS)

ui:
	$(SWIFT) scripts/test-ui.swift $(if $(ARGS),$(ARGS),eval)

evals:
	$(SWIFT) scripts/run-evals.swift $(if $(STAGE),--stage "$(STAGE)",$(if $(MODE),--$(MODE))) $(if $(CASE),--case "$(CASE)") $(ARGS)

evals-list:
	$(SWIFT) scripts/run-evals.swift --list $(if $(STAGE),--stage "$(STAGE)") $(if $(CASE),--case "$(CASE)") $(ARGS)

evals-pipeline:
	$(MAKE) evals MODE=pipeline

evals-suites:
	$(MAKE) evals MODE=suites

packaging:
	$(SWIFT) scripts/build-app.swift $(ARGS)

release:
	$(SWIFT) scripts/release.swift "$(BUMP)" $(ARGS)

release-notes:
	$(SWIFT) scripts/release.swift notes "$(VERSION)"

release-check:
	$(SWIFT) scripts/release.swift check "$(BASE)" "$(HEAD)"

release-cask:
	$(SWIFT) scripts/release.swift cask "$(VERSION)" "$(SHA256)"

icons:
	$(SWIFT) scripts/make-iconset.swift $(ARGS)

clean:
	$(SWIFT) package clean
