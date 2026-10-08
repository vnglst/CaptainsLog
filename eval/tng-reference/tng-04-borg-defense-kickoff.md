# TNG-04: Monday Planning + Borg Defense Kickoff

**Language:** English
**Recording target:** ~12 min (~1,440 words at comfortable speech pace)
**Categories:** work, personal
**Audio filename:** `tng-04-borg-defense-kickoff.m4a`

---

## Raw Script

It's Monday evening, just finishing up, and I want to capture a few things before they slip away.

Starting with the weekend briefly, because it was good and I mentioned the Briar Ridge trip before and today the bird book Lucas ordered arrived. It came through the door this morning while he was at school so I put it on his desk and I could hear him find it the moment he got home. That small moment of joy that you notice as a parent and then just carry with you. Anyway.

The main thing about today was the Borg Defense Inc. kickoff call for the Nexus Sync project. This has been on the schedule for two weeks and I've been both looking forward to it and slightly apprehensive about it. Borg Defense as a client is known for being thorough, demanding, and very process-heavy. Their integration lead is Worf, who I haven't worked with before but whose reputation precedes him. He runs a very tight ship, expects detailed documentation before meetings, expects follow-up within twenty-four hours of every action item, and has a very low tolerance for ambiguity.

The call itself was about ninety minutes. There were ten people on it from their side. Ten. For a kickoff. We were four. That asymmetry tells you something about how seriously they're taking this. Worf opened with a presentation — a presentation! — that covered their integration requirements, their compliance needs, their preferred communication protocols, and a preliminary risk register that they had already populated before the project had officially started. I have to say, it was impressive. Even if it's a lot. It's a lot.

The Nexus Sync project is about integrating our Temporal Archives system with their internal data management systems. The scope involves a bidirectional data sync for operational records, real-time event feeds via Subspace Relay Network, and a reconciliation layer that handles conflicts when both sides update the same record. It is technically complex. Worf is very focused on the compliance piece: Borg Defense handles sensitive operational data and there are strict handling requirements that Federation regulations impose on any system that processes it. Will Riker had already briefed us on this before the call, but Worf's presentation made it even clearer. There will be a compliance audit mid-project, we need to document our data handling procedures before the next meeting, and any access to the sync layer needs to go through an audit log.

Will Riker was on the call and he was very calm and measured, which I appreciated. He confirmed our compliance capability, committed to a detailed data handling document by end of next week, and asked good questions. At one point Q tried to call into the meeting, wrong number apparently, but it happened twice, and the second time Will had to very politely say he had to step away for a moment. I am choosing not to put this in the official meeting notes.

After the call I spent some time in the afternoon doing sprint planning for the Replicator API team. That was a much more comfortable rhythm. Geordi confirmed the internal TDP work is in a good state for the next couple of weeks. Data Chen has the schema design section ready to review. Wesley Crusher is making solid progress on the Holodeck Platform intake form, which I'm pleased about.

One thing I need to flag for next week: the Mission Log System tickets for Nexus Sync need to be created and structured properly before the Borg Defense follow-up meeting. Worf will expect to see a proper project structure in our Mission Log System by then, not just a rough backlog. I know this because Worf actually asked during the call whether we were using a Starfleet Knowledge Base-compatible system for documentation, and when I said yes he said he would want a link to the project space by Friday. So. Friday.

One last thing and then I'm done. Isabel mentioned tonight that she wants to figure out the summer holiday timing. We've been very vague about this. Her family does a gathering every summer and usually it's the first two weeks of July and that might overlap with the Federation Systems mid-year review which Will has tentatively placed in late June or early July. I need to look at the calendar and have a real conversation rather than just nodding and saying yes we'll figure it out. I keep nodding and saying we'll figure it out.

Good day. Demanding but productive. Looking forward to getting into the actual technical work on Nexus Sync because underneath all the process and compliance requirements the problem is actually really interesting.

---

## Polished Version

Monday debrief.

A small personal note first: the bird book Lucas ordered arrived this morning and he found it the moment he got home from school. A good start to the week.

The main event was the Borg Defense Inc. kickoff call for the Nexus Sync project. I'd been looking forward to it and slightly apprehensive — Borg Defense is known for being thorough and process-heavy, and their integration lead Worf has a reputation for tight documentation standards, sub-twenty-four-hour action item turnaround, and zero tolerance for ambiguity. The ninety-minute call had ten people from their side and four from ours. Worf opened with a prepared presentation covering integration requirements, compliance needs, communication protocols, and a preliminary risk register they had already populated before the project officially started.

The Nexus Sync scope: bidirectional data sync between our Temporal Archives system and Borg Defense's internal data management systems, real-time event feeds via Subspace Relay Network, and a reconciliation layer for conflicting simultaneous updates. Technically complex. The compliance requirements are significant — Borg Defense handles sensitive operational data under Federation regulations, a compliance audit is scheduled mid-project, all access to the sync layer must be audit-logged, and a data handling procedures document is due next week. Will Riker handled the compliance commitments calmly and well.

Post-call, afternoon sprint planning for the Replicator API team ran smoothly. Geordi confirmed the internal TDP work is on track. Data Chen has the schema design section ready to review. Wesley Crusher is making good progress on the Holodeck Platform intake form.

Action items for this week: create the Nexus Sync project structure in the Mission Log System and share the Starfleet Knowledge Base project space link with Worf by Friday — he specifically asked for it on the call.

Personal note to follow up: Isabel raised summer holiday planning tonight. Her family's annual gathering is typically the first two weeks of July, which might overlap with the Federation Systems mid-year review. I need to actually look at the calendar this week rather than continuing to defer.

---

## Expected YAML Frontmatter

```yaml
---
date: "2025-04-14"
recording_time: "12:00"
language: English
categories:
  - work
  - personal
tags:
  - client-kickoff
  - enterprise-integration
  - sprint-planning
  - compliance
  - nexus-sync
persons:
  - Worf
  - Will Riker
  - Geordi La Forge
  - Data Chen
  - Wesley Crusher
  - Isabel
projects:
  - Nexus Sync
  - Temporal Archives
  - Replicator API
  - Holodeck Platform
companies:
  - Starfleet Analytics
  - Borg Defense Inc.
  - Federation Systems
entities:
  - Subspace Relay Network
  - Mission Log System
  - Starfleet Knowledge Base
summary: "The Borg Defense Inc. kickoff call for the Nexus Sync project was ninety minutes long with ten people on their side; integration lead Worf's process-heavy approach sets a high documentation bar with a compliance audit mid-project. Sprint planning for the Replicator API was straightforward. A reminder to plan summer holidays before they clash with the Federation Systems mid-year review."
---
```

## Expected Filename

```
2025-04-14-nexus-sync-borg-defense-kickoff.md
```
