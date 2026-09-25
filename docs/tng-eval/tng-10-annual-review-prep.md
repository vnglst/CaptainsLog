# TNG-10: Annual Performance Review Prep

**Language:** English
**Recording target:** ~20 min (~2,400 words at comfortable speech pace)
**Categories:** work, personal-development
**Audio filename:** `tng-10-annual-review-prep.m4a`

---

## Raw Script

Right, so the annual review with Will Riker is in nine days and I've been putting off the preparation in the way that I always put off the preparation, which is to say I've been thinking about it constantly but writing almost nothing down. I'm going to use this recording to force myself to actually structure the year in my head.

I want to approach this the way Guinan told me once: don't list tasks, narrate impact. Because the instinct I have, and I think a lot of engineers share this, is to produce a long list of things I did. I shipped this. I reviewed that. I contributed to this other thing. And that list is technically accurate and completely fails to communicate why any of it mattered. So I'm going to try to narrate impact instead.

Let me go through the main things.

The Warp Drive Migration is the biggest single piece of work this year. When we started the year, our infrastructure was on a legacy system that was slow to change, expensive to operate, and couldn't scale to the data volumes we were projecting for the next two years. The Warp Drive Migration is the multi-phase project to move everything to the LCARS Cluster Grid. I've been the lead engineer on this. We're currently at eighty-five percent through the planned scope. The two cluster environments we've migrated are running more efficiently than the old system — we've seen a reduction in provisioning time from roughly three days to under two hours, and the cost per compute unit has come down by about twenty percent. Those numbers are real and they compound. A two-hour provisioning time versus three days is not just a convenience, it's a different capability. Teams can experiment in ways they couldn't before.

The complications: phase three had the node pool incident I described in an earlier recording, and we had a two-day slip on the migration timeline. But we recovered, we documented the incident properly, and we added the Pattern Buffer version check to the Automated Maintenance Protocol pipeline so it can't happen again. I want to name the slip but frame it as a managed recovery rather than a failure.

Replicator API. This is the new core API layer for Starfleet Analytics. I didn't just contribute to this, I designed the fundamental architecture. The hybrid UQP and TDP approach that we've settled on, the schema design, the choice of the Subspace API Gateway as the routing layer — those are decisions I made and have been advocating for. The API went from a rough design to a working implementation over six months. We haven't launched externally yet, the external launch is planned for next quarter, but internally it's running and it's being used by multiple teams. Holodeck Labs has access to a preview and Neelix has given us positive feedback. The biggest thing I did wrong this year was not establishing test coverage standards on the Replicator API early enough, which contributed to the Sprint 23 authentication regression. I'm going to name that in the review because naming it first is better than having it raised by someone else.

The Tricorder Dashboard. This one is less architecturally complex than the API work but it had real organizational impact. Before the dashboard, the standard way to get a view of how your service was performing was to manually query the Diagnostic Array through a command-line tool that was unfriendly to non-engineers. The Tricorder Dashboard made that data accessible to everyone. Deanna Troi uses it. The business function leads use it. It changed who can see what about how their work is running. That's a real change.

What else. The Federation Systems mid-year review presentation. This was a piece of work I was slightly apprehensive about because presenting to the parent organization feels higher-stakes than internal presentations. I prepared thoroughly, I gave a clear narrative, I didn't get lost in technical detail in a room that didn't want technical detail. Will said after that it was one of the better presentations he'd seen from the team. That was nice. I want to mention this in the review not to pat myself on the back but because it represents a skill that I wasn't sure I had.

Mentoring Wesley Crusher. Mixed results and I want to be honest about that. I set up pair programming sessions that went well. I didn't set up enough structural support for his solo work. He made a significant error in Sprint 23. Since then I've implemented a critical module registry and changed how I run the pair sessions. So the results are mixed and the trajectory is improving.

What I struggled with. The Q2 friction with Data Chen. We had an extended period where code review debates were going longer than they needed to, there was tension about review standards, and it affected the team's velocity on the Replicator API in ways that were not fully visible to Will Riker because they looked like normal work from the outside. I should have had a direct conversation with Data Chen much earlier. I eventually had it, things got better, but I lost about six weeks. That's something I'd do differently.

I should also name the thing about psychological safety that came up in Deanna Troi's workshop. Eighteen months ago I didn't speak up about a design decision I disagreed with, and that decision caused rework later. I want to acknowledge that pattern in the review in the context of what I've learned this year and how I'm different now. It's uncomfortable to name, but I think reviewing openly is how you actually improve.

Goals for next year. I want to be explicit about the staff engineer track. I've been implying it without saying it clearly and I want to say it clearly: I want to move toward a staff engineer role at Starfleet Analytics. That means I need to be operating at a different level, thinking about organizational impact not just team contribution. The Replicator API architecture is an example of that kind of work. I want more of it. I want Will Riker to understand this as an active goal, not a passive hope.

The specific things I want to take on next year: complete Warp Drive Migration phases four and five with multi-cluster operations, lead the Replicator API external launch, and take a more formal technical leadership role in at least one cross-team initiative. Also, I want to improve the documentation culture at Starfleet Analytics. It's a chronic pain point. Teams make good technical decisions and then they're not written down and the knowledge evaporates when people move to other projects. I want to be the person who starts changing that, not just complaining about it.

Presentation structure. I'm thinking of organizing it as: this year in three priorities, one thing I'd do differently, and my goals for next year including the staff engineer conversation. Will appreciates directness. He doesn't need a narrative wind-up. I'll get to the point.

I should also prepare for the question Will always asks, which is: how do you think the team performed as a whole, not just you? I want to be specific there. Geordi has been exceptional. Data Chen is a high-quality contributor whose review standards are assets if channeled well. Wesley is on an improving trajectory. The team overall did significant work this year. I also want to flag that the team needs another senior engineer if we're going to take on the scope of next year's plan without burning out.

Okay. I think that's the shape of it. Nine days is enough time to turn this into something coherent. The thing I needed to do was get the shape out of my head and into something I could look at.

---

## Polished Version

Annual review with Will Riker is nine days away. Using this recording to structure the year's narrative rather than a task list. Guinan's frame: "don't list tasks, narrate impact."

**Warp Drive Migration (lead engineer).** The year started with legacy infrastructure that was slow, expensive, and couldn't scale. The LCARS Cluster Grid migration is now 85% complete: provisioning time reduced from three days to under two hours, cost per compute unit down ~20%. Those numbers represent a genuine capability change, not just efficiency. The phase three node pool incident caused a two-day slip but was recovered cleanly, documented, and resulted in a Pattern Buffer version check added to the Automated Maintenance Protocol pipeline.

**Replicator API (architect).** Designed the fundamental architecture: hybrid UQP/TDP approach, schema design, Subspace API Gateway as routing layer. From rough design to working internal implementation in six months. External launch is next quarter; Holodeck Labs preview feedback from Neelix has been positive. One named failure: not establishing test coverage standards early enough, which contributed to the Sprint 23 authentication regression.

**Tricorder Dashboard.** Changed who can observe service health at Starfleet Analytics. Before it, operational visibility required a command-line tool unfriendly to non-engineers. Now Deanna Troi and business function leads use it directly.

**Federation Systems mid-year presentation.** Led it, prepared thoroughly, delivered a non-technical narrative to a non-technical audience. Will said afterward it was one of the better presentations from the team. Worth naming as a developed skill.

**Mentoring Wesley Crusher.** Mixed. Pair sessions went well; structural support for solo work was insufficient; a significant incident resulted in Sprint 23. Since then: critical module registry implemented, pair session format shifted to teaching thinking over teaching solutions. Trajectory improving.

**What I'd do differently.** Two things: (1) The Q2 friction with Data Chen over code review standards lasted about six weeks longer than it needed to because I delayed a direct conversation. (2) Eighteen months ago I stayed silent on a design decision I disagreed with — the pattern surfaced in Deanna Troi's workshop. I want to name both of these explicitly rather than waiting for them to be raised.

**Goals for next year.** Explicitly: staff engineer track at Starfleet Analytics. More cross-team technical leadership, complete Warp Drive Migration phases four and five, lead the Replicator API external launch, and start actively improving the documentation culture. Also: flag that the team needs another senior engineer to take on next year's scope without burning out.

---

## Expected YAML Frontmatter

```yaml
---
date: "2025-05-12"
recording_time: "12:00"
language: English
categories:
  - work
  - personal-development
tags:
  - performance-review
  - career
  - year-review
  - goals
  - staff-engineering
persons:
  - Will Riker
  - Guinan
  - Data Chen
  - Wesley Crusher
  - Deanna Troi
  - Geordi La Forge
  - Neelix
projects:
  - Warp Drive Migration
  - Replicator API
  - Tricorder Dashboard
companies:
  - Starfleet Analytics
  - Federation Systems
  - Holodeck Labs
entities:
  - LCARS Cluster Grid
  - Automated Maintenance Protocol
  - Subspace API Gateway
summary: "Preparation for the annual review with Will Riker: narrating impact across Warp Drive Migration (85% complete, major capability improvement), Replicator API architecture, Tricorder Dashboard, and the Federation Systems presentation. Names two things done wrong — delayed conversation with Data Chen, and insufficient onboarding for Wesley. Explicit goal: move toward a staff engineer role at Starfleet Analytics."
---
```

## Expected Filename

```
2025-05-12-annual-review-prep-staff-engineer-goals.md
```
