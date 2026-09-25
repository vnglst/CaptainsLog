# TNG-07: Sprint 23 Retrospective

**Language:** English
**Recording target:** ~15 min (~1,800 words at comfortable speech pace)
**Categories:** work
**Audio filename:** `tng-07-sprint-23-retrospective.m4a`

---

## Raw Script

OK this is a retrospective debrief for Sprint 23. I've just come out of the formal retro meeting and I want to record my own thoughts while they're fresh, because the formal meeting notes will capture the structured things but not the texture of the conversation.

Let me start with what went well, because I want to make sure that doesn't get lost in what comes next. The clear win this sprint was the Tricorder Dashboard reaching production. It's been in staging for two weeks, we had positive feedback from Deanna Troi and a couple of other internal users, and on Thursday we did the production deploy. Automated Maintenance Protocol ran cleanly, zero downtime, the rollout went in phases as intended, and by end of day Thursday it was fully live. I got a message from Deanna saying that the diagnostic panels were noticeably faster than the old system and the new layout was much clearer. That was nice to receive. The team worked hard on that. Geordi, specifically, had been the one to identify the LCARS Interface Layer performance issue that was causing slowness in the diagnostic panels and he fixed it in a way that was both correct and clean. Good work.

Also went well: Nexus Sync progress. We're two weeks into the Borg Defense engagement and despite my initial apprehension about the process overhead, the structure that Worf insisted on has actually been clarifying. Having all the compliance requirements documented before we started building means we haven't had any surprises. The bidirectional sync for the first data type is about seventy percent complete. Worf sent a brief message saying they were pleased with progress. From Worf that might as well be a standing ovation.

Now. What didn't go well. I have to talk about the authentication regression.

Wednesday afternoon there was an incident. The Replicator API started returning authentication errors for a subset of clients. Not all clients, just those using a specific token type. It lasted about four hours before we got it resolved. When we traced the root cause it was a change that Wesley Crusher had made to the authentication module on Tuesday, as part of a task that was supposed to be a small refactor to clean up some legacy handling code. The change itself was not incorrect, technically speaking, but it introduced a behavior difference for clients using the older token format, and that difference wasn't covered by any existing tests. And the change had been reviewed — Wesley asked Data Chen to review it, Data Chen approved it. The PR was green, the test suite passed, and then production had a four-hour incident.

I want to be careful about how I'm framing this because it's not about fault, it's about process. There are three things I want to say.

First: the test coverage for the authentication module is not adequate. This isn't a Wesley thing, this predates Wesley, the module has had thin test coverage since it was first written eighteen months ago. We've been meaning to address it and we keep not addressing it. This incident is the consequence of that.

Second: code review caught the style and structure but missed the semantic implication. That's not a reviewer failure, it's a review process limitation. When you're reviewing code you're looking at what it does. You're not necessarily running a mental simulation of all the clients who might be affected by a behavior change in an authentication path. The right tool for that is tests, not human review. Back to the first point.

Third: Wesley's onboarding process isn't adequate for the level of ownership we've been giving him. He's been taking on tasks in the Replicator API authentication module after two sprints. That's significant code. I should have set up a more formal onboarding structure where work on critical modules like authentication has an explicit sign-off from Geordi or me, not just a peer review. That's something I'm implementing next sprint: a critical module registry with an explicit senior review requirement for any change to listed modules.

Data Chen raised the test coverage concern in the formal retro and it got a bit heated for a moment. He pointed out the coverage gap in very direct terms and Will Riker asked how it had been allowed to persist and there was a moment of mutual discomfort. I stepped in and suggested we separate the incident post-mortem from the retro because mixing them was going to make the retro unproductive. Will agreed. We're doing a dedicated post-mortem next Tuesday. That should give everyone time to think and write things down rather than processing it live in a room.

Will Riker also raised something else in the retro. He wants to add a dedicated QA step before any production deploy. Right now we rely on the Automated Maintenance Protocol test suite and staging deployment as our quality gates. Will's view is that for something like the Replicator API, which is client-facing and affects production traffic immediately, we should have a human sign-off step in addition to the automated checks. I understand the instinct and I have mixed feelings about it. A manual QA step adds latency to deployment. It also adds a bottleneck. But it would have caught the authentication regression because someone looking at the pre-production environment would have run the token type that was affected. I'm going to give it a try next sprint and see how it feels.

The other thing I want to note is team dynamics. Wesley is in a tricky position right now. He knows about the incident, he knows it was his change, he messaged me privately after the retro and said he was sorry. And I told him what I genuinely believe: that the process failed before his change reached production, that the test coverage was the root cause, and that his job right now is to write the post-mortem and to make sure he fully understands the authentication module before touching it again. I don't want him to be discouraged. He's capable. He just needs more structured guidance than we've been giving him.

Planning for Sprint 24: I want to dedicate about thirty percent of capacity to test coverage on the authentication module. Unromantic, not exciting, but necessary. Geordi is continuing on the Warp Drive Migration second cluster region. Data Chen is finishing the schema review section of the Replicator API architecture. Wesley will be pairing with me for the first week on the authentication test suite, which will serve as an education in the module and an accountability structure at the same time.

And that's the sprint. Difficult in the middle, productive at the edges.

---

## Polished Version

Sprint 23 retrospective debrief, recorded just after the formal meeting.

**What went well.** The Tricorder Dashboard reached production on Thursday: Automated Maintenance Protocol deployed cleanly, zero downtime, phased rollout. Deanna Troi reported noticeably faster diagnostic panels and improved layout. Geordi had identified and fixed an LCARS Interface Layer performance issue in staging that made the production result solid.

Nexus Sync is progressing well — two weeks in with Borg Defense, the documentation structure Worf required upfront has removed surprises, the bidirectional sync for the first data type is seventy percent complete. Worf indicated they were pleased, which is approximately a standing ovation.

**The authentication regression.** Wednesday afternoon: the Replicator API returned authentication errors for clients using a specific token type for approximately four hours. The root cause was a change by Wesley Crusher to the authentication module — a legitimate small refactor that introduced a behavior difference for older token formats not covered by existing tests. The change had been reviewed by Data Chen and approved; the test suite passed; the incident still happened.

Three observations: (1) The authentication module has had thin test coverage for eighteen months — this incident is the long-deferred consequence. (2) Code review catches structure and style; it doesn't replace tests for catching behavioral regressions in critical paths. (3) Wesley's onboarding hasn't been structured enough for ownership of critical modules after two sprints. A critical module registry with explicit senior review requirements will be implemented in Sprint 24.

The retro got briefly heated when Data Chen raised the coverage gap directly and Will Riker asked how it had persisted. The incident post-mortem was separated from the retro; it runs on Tuesday.

**Process change: QA sign-off.** Will Riker wants a human QA sign-off step before production deploys of the Replicator API, in addition to automated gates. Adding latency and a bottleneck — but it would have caught this regression. Piloting in Sprint 24.

**Team dynamics.** Wesley messaged after the retro to apologize. The response: the process failed before his change reached production; his job now is to write the post-mortem and deeply understand the authentication module. He's capable and needs structure more than reprimand.

**Sprint 24 plan:** ~30% capacity on authentication test coverage, Geordi on Warp Drive Migration cluster region 2, Data Chen on schema review, Wesley pairing on the test suite.

---

## Expected YAML Frontmatter

```yaml
---
date: "2025-04-25"
recording_time: "12:00"
language: English
categories:
  - work
tags:
  - retrospective
  - agile
  - tech-debt
  - incident
  - team-dynamics
  - sprint-planning
persons:
  - Wesley Crusher
  - Data Chen
  - Will Riker
  - Geordi La Forge
  - Deanna Troi
projects:
  - Tricorder Dashboard
  - Replicator API
  - Nexus Sync
  - Warp Drive Migration
companies:
  - Starfleet Analytics
  - Borg Defense Inc.
entities:
  - Automated Maintenance Protocol
  - LCARS Interface Layer
summary: "Sprint 23 retrospective: the Tricorder Dashboard went to production cleanly and Nexus Sync is on track, but a regression in the Replicator API authentication module caused a four-hour incident. Root causes were insufficient test coverage and immature onboarding for Wesley Crusher on critical modules. A critical module registry and a manual QA sign-off step will be piloted in Sprint 24."
---
```

## Expected Filename

```
2025-04-25-sprint-23-retro-auth-incident-tricorder-dashboard.md
```
