# TNG-11: DDIA Book Reflection

**Language:** English
**Recording target:** ~15 min (~1,800 words at comfortable speech pace)
**Categories:** work, personal-development
**Audio filename:** `tng-11-ddia-book-reflection.m4a`

---

## Raw Script

I just finished "Designing Data-Intensive Applications" by Martin Kleppmann and I want to talk through what I got from it while it's still fresh. Data Chen recommended this to me about six months ago and I kept saying I'd read it and then not reading it and then I finally committed to it and read the last third this past week.

First thing I want to say: Data Chen was completely right and I should have read it six months ago. It's one of those books that makes you feel like your mental model of a whole area has been quietly wrong and you're only now getting the correct version. And not in an embarrassing way, more like you had a map that was mostly right but missing several important features, and now you have a better map.

Let me walk through the things that stuck.

The consensus section. The treatment of distributed consensus in the book — and specifically the explanation of why consensus is hard and what the actual constraints are — is the clearest I've ever read. The way Kleppmann explains the relationship between the CAP theorem and the more nuanced reality of real-world distributed systems, where you're not choosing between just consistency and availability but between different categories of consistency guarantees, with different latency implications for each — I had a model of this that was correct in the broad strokes and wrong in the details. The book corrected the details.

The event sourcing section got me most excited. And this is where I have to flag that I have a bias here because the Temporal Archives project has been something I've been thinking about re-architecting for a while and the event sourcing pattern maps directly to what I want to do there. The basic idea of event sourcing is that you don't store the current state of a thing, you store the sequence of events that produced the current state. The state is always derivable from the event log. This has some really powerful properties. The event log is an append-only truth. You can replay it. You can project different views of the data from the same event log. You can debug by replaying history. But the section I kept re-reading was the part about replication lag. When you have a Subspace Relay Network acting as your event backbone, the consumers of that stream are always going to be slightly behind the producers. How slightly depends on a lot of things: network latency, consumer processing time, partition counts. But there's always a lag and you have to design for it explicitly rather than pretending it doesn't exist. The Temporal Archives project right now writes directly to the Isolinear Core Database synchronously. That makes reads consistent but it makes writes slow and it makes the architecture rigid. The event sourcing model would flip that: writes go to the Subspace Relay Network, reads are eventually consistent but much faster because they're reading from materialized views rather than the primary store.

The discussion with Geordi. I pulled Geordi aside after a sprint planning meeting and described this idea. Geordi's response was: yes that's architecturally interesting, and have you thought about the operational complexity? He's right to ask. Event sourcing adds observability and debuggability but it also adds operational surface area. You need to manage the event log, you need to handle schema evolution of events (much harder than schema evolution of a relational table), you need consumer offset management, you need replay tooling. These are not trivial. Geordi's specific concern was around schema evolution of events. In the Isolinear Core model, adding a column to a table is a migration. It's bounded. In an event log model, you're adding a field to an event type that has existing events in the log that don't have that field, and any consumer that reads old events needs to handle the absence. His word for this was "fragile." I think "requires discipline" is closer to right, but his concern is legitimate. I'm not going to redesign Temporal Archives based on a book chapter and a sprint planning conversation. But I am going to write an internal document exploring the idea and share it with the team as a discussion starter.

The part of the book that made me slightly uncomfortable is the section on replication strategies and what happens when you actually look at how most data systems behave under partition. There are paragraphs in there that describe failure modes that I recognized from things that have happened in systems I've worked on, where I understood the symptom at the time but not the cause. The double-write problem, specifically. We had an incident a while back in the Replicator API where data was inconsistent between two components and we fixed the symptom without understanding the root cause. Reading the double-write section of the book I'm now fairly confident I know what was actually happening. I should probably write that up somewhere as well.

The broader thing I'm sitting with after finishing the book is the degree to which a lot of the design decisions in the Replicator API were made intuitively rather than analytically. That's not unique to this project, most design decisions at speed are intuitive. But some of the decisions were made intuitively in ways that don't match the framework the book provides, and a couple of them would probably be different if I'd read the book first. Not wrong exactly, just differently shaped. It's a useful lesson about keeping up with the theoretical foundations while also staying in the practical work. These aren't separate activities. The theory tells you what your intuitions are approximating.

I want to write an internal document and present it to the team as a lunch and learn. I think the concepts in the book — specifically consensus, event sourcing, and the replication lag framing — are directly relevant to two active projects: Temporal Archives and the Replicator API. I'm going to propose this to Will Riker. The goal would be to share the framing with Data Chen and Geordi and get them reading the same material so we have a shared vocabulary. We already have partial shared vocabulary from previous work, but this book would upgrade it.

Data Chen, when I told him I'd finally read it, said: took you long enough. Which is fair.

---

## Polished Version

Just finished "Designing Data-Intensive Applications" by Martin Kleppmann (recommended by Data Chen six months ago). Recording the key takeaways while fresh.

**Distributed consensus.** The clearest treatment I've read. The book corrects the over-simplified CAP theorem framing into a more nuanced understanding of consistency-availability tradeoffs: different categories of consistency guarantees carry different latency implications, and real-world systems make these tradeoffs explicitly or accidentally. My prior mental model was correct in broad strokes and wrong in the details.

**Event sourcing and the Temporal Archives connection.** The event sourcing pattern — storing the sequence of events that produced state rather than the state itself — maps directly to a Temporal Archives re-architecture I've been considering. Key properties: append-only truth, replayable, multiple projectable views from a single event log. The section on Subspace Relay Network replication lag is the crucial practical constraint: consumers are always somewhat behind producers, and the design must account for this explicitly. Current Temporal Archives writes synchronously to the Isolinear Core Database (consistent reads, rigid architecture, slow writes); the event sourcing model would move writes to the Subspace Relay Network with eventually-consistent materialized views for reads.

**Conversation with Geordi.** Geordi's response to the event sourcing idea: architecturally interesting, but have you thought about operational complexity? His specific concern: schema evolution of event types is harder than relational migrations — existing events in the log lack new fields, and every consumer must handle their absence. His word was "fragile." I'd say "requires discipline" — but the concern is legitimate. Not redesigning Temporal Archives from a book chapter alone; will write an internal discussion document instead.

**The double-write realization.** A section on replication failure modes under partition described something I recognized from a past Replicator API incident — data inconsistency between two components that we fixed symptomatically. The double-write section gives me the probable root cause in retrospect. Worth writing up.

**Broader reflection.** Several Replicator API design decisions were made intuitively rather than analytically. Some of them would be shaped differently with this book's framework. Theory and practical work aren't separate activities: the theory tells you what your intuitions are approximating.

**Next steps.** Propose a lunch-and-learn for the team (Geordi, Data Chen) covering consensus, event sourcing, and replication lag — building shared vocabulary for Temporal Archives and Replicator API. Write the internal document on event sourcing as a discussion starter for Temporal Archives.

Data Chen's response when told the book was finally done: "Took you long enough." Fair.

---

## Expected YAML Frontmatter

```yaml
---
date: "2025-05-09"
recording_time: "12:00"
language: English
categories:
  - work
  - personal-development
tags:
  - reading
  - distributed-systems
  - event-sourcing
  - data-engineering
  - learning
persons:
  - Data Chen
  - Geordi La Forge
projects:
  - Temporal Archives
  - Replicator API
companies:
  - Starfleet Analytics
entities:
  - "Designing Data-Intensive Applications (Martin Kleppmann)"
  - Subspace Relay Network
  - Isolinear Core Database
  - event sourcing
  - distributed consensus
summary: "Reflections after finishing 'Designing Data-Intensive Applications' by Martin Kleppmann: the consensus and event sourcing sections are directly applicable to the Temporal Archives project and a past Replicator API incident. A discussion with Geordi surfaced legitimate operational complexity concerns about event sourcing. Plans to write an internal document and run a lunch-and-learn for the team."
---
```

## Expected Filename

```
2025-05-09-ddia-event-sourcing-temporal-archives-application.md
```
