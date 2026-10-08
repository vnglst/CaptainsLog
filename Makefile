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
	bash scripts/isolated-check.sh $(SWIFT) run -c "$(CONFIGURATION)" run-tests $(ARGS)

tests-unit:
	bash scripts/isolated-check.sh $(SWIFT) run -c "$(CONFIGURATION)" run-tests --unit $(ARGS)

tests-coverage:
	bash scripts/isolated-check.sh bash scripts/test-coverage.sh $(ARGS)

tests-updates:
	bash scripts/isolated-check.sh bash scripts/test-updates.sh $(ARGS)

tests-release:
	bash scripts/test-release-tooling.sh $(ARGS)

tests-evals:
	ruby scripts/test-evals.rb $(ARGS)

tests-runtime:
	bash scripts/test-runtime.sh

tests-enrich:
	$(MAKE) build CONFIGURATION=debug
	bash scripts/isolated-check.sh bash scripts/test-enrich-eval.sh $(ARGS)

tests-model:
	bash scripts/isolated-check.sh bash scripts/test-model-smoke.sh $(ARGS)

tests-recorder:
	bash scripts/isolated-check.sh bash scripts/test-recorder-hardware.sh $(ARGS)

ui:
	bash scripts/test-ui.sh $(if $(ARGS),$(ARGS),eval)

evals:
	bash scripts/run-evals.sh $(if $(STAGE),--stage "$(STAGE)",$(if $(MODE),--$(MODE))) $(if $(CASE),--case "$(CASE)") $(ARGS)

evals-list:
	bash scripts/run-evals.sh --list $(if $(STAGE),--stage "$(STAGE)") $(if $(CASE),--case "$(CASE)") $(ARGS)

evals-pipeline:
	$(MAKE) evals MODE=pipeline

evals-suites:
	$(MAKE) evals MODE=suites

packaging:
	bash scripts/build-app.sh $(ARGS)

release:
	$(SWIFT) scripts/release.swift "$(BUMP)" $(ARGS)

release-notes:
	$(SWIFT) scripts/release.swift notes "$(VERSION)"

release-check:
	$(SWIFT) scripts/release.swift check "$(BASE)" "$(HEAD)"

release-cask:
	$(SWIFT) scripts/release.swift cask "$(VERSION)" "$(SHA256)"

icons:
	bash scripts/make-iconset.sh $(ARGS)

clean:
	$(SWIFT) package clean
