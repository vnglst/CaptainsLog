# TNG-02: Replicator API Technical Architecture

**Language:** English
**Recording target:** ~20 min (~2,400 words at comfortable speech pace)
**Categories:** work, technical
**Audio filename:** `tng-02-replicator-api-architecture.m4a`

---

## Raw Script

Alright so I need to think through this properly and I feel like recording it will help me organize my thoughts. This is about the Replicator API architecture decision. We've been going back and forth for a few weeks now and I think I've reached a point where I know what I think, but I want to walk through the reasoning out loud to make sure it holds together.

The core question is this: should the Replicator API use Universal Query Protocol, which I'll just call UQP, or Transporter Data Protocol, which is TDP? And the answer I've been arriving at is: both, but in different layers. Let me explain why.

So first let me recap the context because if I'm going to share this reasoning with Geordi and possibly Will Riker I want it to be coherent. The Replicator API is our main API layer. It's the thing that external clients call to access our systems, and it's also the thing that our own internal services call to communicate with each other. That dual role is actually the root of the tension here.

For external clients, the main user right now is Holodeck Labs. Neelix, who is their product manager, has been very clear that they need flexibility. Their use case is a frontend application that queries lots of different combinations of entities and fields, and they want to be able to build those queries dynamically on the client side. If you're familiar with how UQP works, that's exactly what it's designed for. You define a schema, you expose a single endpoint, and the client can ask for exactly what it needs in whatever shape it needs it. No over-fetching, no under-fetching. Neelix loves this. He sent me three separate messages over the past two weeks expressing enthusiasm about UQP and that we're considering it.

On the other hand, Borg Defense Inc. is our other significant client and they have a different profile entirely. They care about performance above almost everything else. They're processing large volumes of data through the Nexus Sync project and latency is a direct cost to them. TDP is more suited there because it's a binary protocol, it compresses well, streaming is first-class, and connection overhead is much lower. Our internal benchmarks on a quick prototype showed that for the specific read patterns Borg Defense uses, TDP was about forty percent faster at the ninety-fifth percentile latency than UQP would be. That's a real gap.

So I spent most of last Tuesday in a pairing session with Data Chen working through this. Data is meticulous about this kind of analysis and he pushed me on every assumption. At one point he asked me to prove that the UQP over-fetching problem was actually a problem in practice and not just a theoretical concern, and I had to admit I hadn't measured it. So we built a small prototype and measured it. And the over-fetching is real but it's only significant if the client is doing it badly, which a good client library helps you avoid. So that was a useful data point. Data Chen also raised the question of schema versioning. With UQP you have a schema and schema evolution has specific constraints around backwards compatibility. You can't remove fields that existing clients use. You have to deprecate them first. That's a governance burden. With TDP you have protobuf definitions and those have their own versioning rules but they're more explicit. It was a really good pairing session actually. We didn't agree on everything but we got much clearer on what the actual tradeoffs were versus what we just assumed the tradeoffs were.

Then on Wednesday I spent time sketching an architecture that I think resolves the tension. The key insight is that the external API and the internal service communication have different requirements and they don't actually need to use the same protocol. So what I'm proposing is this: we use UQP for the external API surface, the thing that Holodeck Labs and any future external clients call. And we use TDP for internal service-to-service communication, which is what Borg Defense would actually be calling through the Nexus Sync integration. Now, you might say, does Borg Defense call us externally or internally? They're technically an external client but the Nexus Sync integration goes through a dedicated integration layer, not through the public API surface. So they would use TDP through that path.

This has a few nice properties. First, external clients get the flexibility of UQP. Second, internal traffic gets the performance of TDP. Third, we don't have to maintain two separate external API surfaces, which would be a maintenance and consistency nightmare. The downside is that the integration layer for Nexus Sync becomes a translation point. When an external TDP call comes in through that dedicated path, it has to be translated to something the internal services understand, which they speak via TDP anyway. So actually in the Nexus Sync case the data flows TDP all the way. That's probably fine.

The Subspace API Gateway sits in the middle of all this. It's the actual process that handles incoming requests. For UQP requests it does schema validation, query parsing, the resolver chain. For TDP it does service discovery, load balancing, the streaming connections. I've already checked and our current version of the Subspace API Gateway supports both. There's no need to run two separate gateway processes. One gateway, two protocol handlers. That simplifies deployment.

Then there's the question of the Isolinear Core Database. This doesn't change at all. The database is downstream of all of this and it just responds to whatever the resolver layer asks it. We're using Isolinear Core for our primary transactional data and that won't change regardless of which protocol the API layer speaks. The only thing that might change is query patterns, because UQP resolvers tend to generate more individual database queries than a well-designed TDP service might. But that's something we can optimize over time with proper data loader patterns for the UQP resolvers.

Wait, actually, I want to flag one more thing. There's a concern I haven't fully addressed which is schema introspection. UQP supports introspection out of the box, which means any client can query the API to discover the full schema. That's great for developer experience but it's also an information exposure. We'd need to think about whether we're comfortable with Borg Defense being able to introspect the full schema if they happen to access the public surface. Probably we'd put access controls on introspection. But this is worth raising explicitly with Will Riker and probably also with Worf on the security side before we finalize.

Let me also just note one thing about timeline. If we go with this hybrid approach, the UQP external surface is the higher-effort component to build. The TDP internal path is already partially there from some previous work. So the critical path is UQP. I'd estimate three to four sprints to get to a fully stable external UQP API with proper schema definition, resolver implementation, error handling, and the data loader layer. That assumes Data Chen and I are the primary implementers, which I'd want to confirm with Will.

The next step is to get a document written up and reviewed. I want Geordi to weigh in on the internal TDP architecture because he has more experience with high-throughput service-to-service patterns than I do. And I want Data Chen to review the schema design section because he has strong opinions about nullable fields and union types that have always proven right in retrospect even when they're annoying in the moment. Then take it to Will for sign-off on direction before we get into detailed implementation.

One more thing. I had a brief conversation with Neelix from Holodeck Labs, just a quick check-in call, and he raised something I hadn't considered. He said their frontend team is planning to build a real-time update feature that shows live changes to entities as they happen. That kind of streaming subscription feature is something that UQP supports as a first-class operation type, called subscriptions in UQP. TDP also supports bidirectional streaming but the pattern is different and the client library ecosystem for it is more limited. So that's actually another point in favor of UQP for the external surface. Good that he mentioned it now rather than after we'd built everything.

So to summarize where I've landed: UQP external, TDP internal, Subspace API Gateway handles both, Isolinear Core unchanged, need to address schema introspection access controls, timeline is three to four sprints for the UQP surface, next step is to write the architecture doc and circulate for review. I feel pretty good about this. The pairing session with Data Chen was the thing that made it concrete. Looking forward to getting Geordi's input because I think he'll push back in useful ways.

Alright. That's it for this one.

---

## Polished Version

This is a thinking-aloud session on the Replicator API architecture decision: Universal Query Protocol (UQP) versus Transporter Data Protocol (TDP). After several weeks of back-and-forth, the conclusion is a hybrid: UQP for the external API surface, TDP for internal service-to-service communication.

**Context and the core tension.** The Replicator API serves two different caller profiles. Holodeck Labs, via their product manager Neelix, needs query flexibility — their frontend dynamically assembles requests for different entity combinations, and UQP is the right fit. Borg Defense Inc., on the other hand, requires low latency for the Nexus Sync integration. Benchmarks from a quick prototype showed TDP was approximately forty percent faster at the ninety-fifth percentile for their read patterns. These requirements are in tension if we try to pick one protocol for everything.

**The pairing session with Data Chen.** A full Tuesday was spent with Data Chen analyzing the tradeoffs. He pushed back on whether UQP over-fetching was actually a problem in practice — measurement showed it's real but largely avoidable with good client library usage. He also raised schema versioning: UQP requires explicit deprecation before field removal, creating governance overhead. TDP's protobuf definitions are more explicit. Both points sharpened the proposal rather than invalidating it.

**The hybrid architecture.** The external API surface uses UQP, serving Holodeck Labs and future external clients. Internal service-to-service traffic uses TDP. The Nexus Sync integration for Borg Defense routes through a dedicated integration layer — not the public API surface — so it uses TDP end-to-end. The Subspace API Gateway runs as a single process with handlers for both protocols; no separate deployments are needed. The Isolinear Core Database is unaffected; it sits downstream and responds to whatever the resolver layer requests.

**Open items.** UQP schema introspection is enabled by default and exposes the full schema — access controls on introspection need to be designed and reviewed with Worf before launch. Also, Neelix mentioned their team plans a real-time update feature requiring streaming subscriptions; UQP supports this natively as first-class subscriptions, which further validates the external UQP choice.

**Timeline.** The UQP external surface is the critical path: three to four sprints for stable schema definition, resolver implementation, error handling, and data loader layer. The TDP internal path is largely pre-built. Data Chen and I would be primary implementers — need to confirm with Will Riker.

**Next steps.** Write an architecture doc for review. Geordi La Forge reviews the internal TDP architecture (high-throughput service patterns). Data Chen reviews the schema design section (nullable fields, union types). Then take to Will Riker for directional sign-off before detailed implementation begins.

---

## Expected YAML Frontmatter

```yaml
---
date: "2025-04-08"
recording_time: "12:00"
language: English
categories:
  - work
  - technical
tags:
  - api-design
  - uqp
  - tdp
  - architecture
  - performance
  - replicator-api
persons:
  - Data Chen
  - Geordi La Forge
  - Will Riker
  - Neelix
  - Worf
projects:
  - Replicator API
  - Nexus Sync
  - Holodeck Platform
companies:
  - Starfleet Analytics
  - Holodeck Labs
  - Borg Defense Inc.
entities:
  - Universal Query Protocol (UQP)
  - Transporter Data Protocol (TDP)
  - Subspace API Gateway
  - Isolinear Core Database
  - LCARS Cluster Grid
summary: "Thinking-aloud session on the Replicator API protocol choice: proposes UQP for the external surface (flexibility for Holodeck Labs) and TDP for internal service communication (performance for Borg Defense). The Subspace API Gateway handles both; a three-to-four sprint timeline for the UQP surface with Geordi and Data Chen reviewing before Will Riker sign-off."
---
```

## Expected Filename

```
2025-04-08-replicator-api-uqp-tdp-architecture-decision.md
```
