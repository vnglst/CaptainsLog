---
id: TASK-29
title: Remove unused legacy UI components
status: Verify
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-09 05:14'
labels:
  - distribution
dependencies: []
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove unused legacy UI and common components, cleaning up as much unused code as possible within this scope. The owner authorized removal during backlog refinement on 2026-10-08 and confirmed there are no external Swift package users, so external compatibility is not a constraint.

The historical review identified older ContentView and FirstRunView, LCARS controls, and entry-row, microphone-selector, delete-confirmation and model-status views as candidates. The current launcher uses FieldNotesContentView. Check current uses, previews, debug flags and resource dependencies to distinguish unused components from active functionality before removal. DesignFixtures and DemoMode were active debug seams, and the vendored sqlite-vec header was a required public include surface; the historical review alone did not establish that these were unused.

This task delivers cleanup rather than only a list of removal candidates.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Unused legacy UI and common components are removed rather than only identified; external package compatibility does not block removal.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Trace launcher, active UI, tests, debug seams and resource consumers. Remove the unused legacy UI tree and dependencies used exclusively by it, retaining active common helpers. Build and run deterministic checks and the isolated repository-fixture pipeline; record verification and open a review PR.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The September 26 review removed no code and left the legacy UI candidates unproven. On October 8 the owner authorized removal and confirmed that external package compatibility is not a constraint.

The October 8–9 dependency review found that the launcher uses FieldNotesContentView exclusively. No in-repository previews or debug paths use the old ContentView/FirstRunView tree. Its LCARS controls, legacy theme shims and Antonio font registration were exclusive dependencies of that unused tree. They have been removed, together with the font/license resources and obsolete resource-bundle handling in packaging, the native UI harness and coverage inputs. The active Field Notes onboarding, controls and entry behavior, shared CLState and hex-color helpers, DesignFixtures/DemoMode, and required sqlite-vec include surface remain.

Verification: a fresh Swift build and all 209 deterministic tests passed. After rebasing onto the merged Make/license work, make build and make tests passed again with all 209 tests; release app/CLI packaging and strict deep signature verification passed. The packaged CLI listed the three isolated synthetic entries. Native Settings → third-party notices → Logs interaction passed without the obsolete font bundle. A verified 15-second silent window-only video captures Settings and notices; a separate screenshot shows the three fixture Logs entries. The verification app was closed. Recording hardware and active processing controls were not exercised in that UI check.

The complete repository audio fixture pipeline finished successfully in 704.5 seconds, with all five stage validations passing and artifact/category, resume immutability and search readback assertions passing. The source, prompts and fixtures used by that run are unchanged by the subsequent rebase onto the merged Make and MIT work. The focused Make filename smoke also passed and produced the exact expected authentication-deployment filename.

Semantic review found raw transcription substitutions for foldertje, side-project and the preference for a local model. Cleanup repaired the folder/local-model wording but retained science project; the cleanup reference also contains that wording although the transcription ground truth says side-project. Cleanup preserves the substantive workflow in three paragraphs rather than the reference’s six. The category and voice-log filename match the references. Enrichment preserves the cleaned body, named entities and grounded tags. Its summary is English despite Dutch language metadata, as is the supplied reference; recording time 20:20 is the pipeline’s inferred value rather than the spoken half-eight. Structural success does not resolve those quality limits. No baseline comparison attributes any semantic change to this UI cleanup; final quality judgment remains with the owner.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed the unused legacy UI tree, its exclusive LCARS controls and Antonio resources; retained active Field Notes, shared helpers and debug seams. Fresh and rebased Make builds, all 209 tests, signed release packaging, isolated native UI, full audio fixture pipeline with five passing stage checks/resume/search assertions, and the focused filename smoke passed. Detailed semantic findings and native review limits are recorded for owner review.
<!-- SECTION:FINAL_SUMMARY:END -->
