---
date: "2026-09-18"
recording_time: "20:40"
language: English
categories:
  - side_project
tags:
  - local-ai
  - prototype
  - privacy
persons:
  - Geordi La Forge
projects:
  - Holodeck Home
companies: []
summary: "The Holodeck Home prototype can now answer a small set of household questions from local notes without a network connection. Next I need to make the source note visible for every answer and test what happens when no note matches."
---

I spent the evening on Holodeck Home, the little local assistant I have been building for our household notes. The prototype can now find the recycling schedule, the boiler manual, and the list of plants that need watering. I disconnected Wi-Fi before testing it, and the retrieval path still worked. That matters more to me than making the answers sound polished.

The rough edge is provenance. The answer about the boiler pressure was correct, but the screen did not show which paragraph it used. I want each answer to open the underlying note, with the matching passage highlighted. If there is no relevant note, it should say so plainly. I also need to try the Dutch versions of a few questions; at the moment I have only tested English.

Geordi La Forge offered to look at the indexing code next week. I will clean up the small fixture set first so he can reproduce the behavior without seeing anything from our actual home notes.
