---
id: TASK-23
title: License CaptainsLog under MIT and reference third-party licenses
status: Verify
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 18:30'
labels:
  - publication
dependencies: []
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
License CaptainsLog's own source code under the MIT license. The owner chose MIT during backlog refinement on 2026-10-08 and requested conventional open-source license organization with references to third-party licenses.

Use the standard MIT license text for the project's code and reference separate third-party notices alongside it, keeping the components' own license terms intact. Review the shipped dependency set, font, native runtime, downloaded models and approved fixture attributions. Preserve the Antonio font's SIL Open Font License, sqlite-vec's MIT/Apache notices, applicable Swift package and llama.cpp notices, and model-source/license information. Verify that the release app contains the required notice copies. Record any rights questions before announcing a release.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 CaptainsLog's own source code is licensed under MIT using the standard license text.
- [x] #2 Third-party licenses are referenced alongside the project license using conventional open-source organization, while retaining their own terms and notices.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Add the standard MIT license for CaptainsLog, reference the existing third-party notices without relicensing components, include the project license in release bundles, and verify the packaged notice copies.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-08: Added the standard MIT grant for Koen van Gilst with third-party references outside the grant, and clarified the separate terms in README and notices. Audited resolved Swift package license filenames and found Argmax ships a plural NOTICES file that packaging omitted; packaging now includes it alongside LICENSE and NOTICE copies. Release-bundle verification is in progress.

2026-10-08 verification: release packaging completed. All 25 project and third-party license/notice files match their source bytes in both the signed app and release ZIP, including Argmax NOTICES. App deep/strict and CLI strict signature checks passed. Reviewed the 13 resolved Swift package license sets, native runtime, sqlite-vec and Antonio notices; retained downloaded-model references and fixture rights attribution without extending MIT to those materials.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added the standard MIT project license with separate third-party references, README licensing guidance and bundled project LICENSE. Corrected plural NOTICES collection. Release packaging passed; all 25 notice files were byte-compared in the signed app and ZIP, and app/CLI signatures verified. Ready for owner license and attribution review.
<!-- SECTION:FINAL_SUMMARY:END -->
