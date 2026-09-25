---
date: "2026-09-23"
recording_time: "16:45"
language: English
categories:
  - work
tags:
  - deployment
  - accessibility
  - dashboard
persons:
  - Deanna Troi
  - Wesley Crusher
projects:
  - Tricorder Dashboard
companies:
  - Starfleet Analytics
summary: "The Tricorder Dashboard reached staging with the new incident timeline. Deanna found a keyboard focus problem during review, and Wesley fixed it before the afternoon smoke test."
---

The Tricorder Dashboard's incident timeline is finally in staging. The data side was uneventful: the Automated Maintenance Protocol completed, the backfill matched our sample incidents, and the timeline loaded in under a second for the largest test account. That was a relief after last week's slow query investigation.

Deanna Troi walked through the screen with a keyboard and found that focus disappeared when the incident drawer closed. The content stayed visible, but the next Tab press jumped all the way to the top of the page. Wesley Crusher traced it to the drawer's removal animation and returned focus to the row that opened it. We repeated the smoke test at narrow window widths and with VoiceOver before calling the staging deployment complete.

I wrote down the focus case for the release checklist. It was exactly the sort of issue that a mouse-only review would have missed.
