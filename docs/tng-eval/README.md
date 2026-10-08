# TNG Eval Set — Scripts and Ground Truth

This folder contains the complete scripts and ground truth for the Star Trek TNG synthetic evaluation corpus. There are 13 entries: 11 in English, 1 in Dutch, 1 in German.

## Active suite versus reference corpus

This is a reference corpus, not the current runner's case list. The active suites are the committed audio/input/expected files under `eval/{transcribe,cleanup,categorize,filename,enrich}`. Use `bash scripts/run-evals.sh --list` and [the evaluation workflow](../EVALUATIONS.md) to discover and run them. These reference scripts do not automatically participate in release gates.

Corpus expansion is owner-selected backlog work. When selected, derive synthetic fixtures from these scripts and ground truth; do not use personal recordings. Keep narration and expected stage outputs paired and review their semantics before adding them to the active directories.

## The TNG Universe

**Narrator:** Works at Starfleet Analytics as a senior engineer. Never explicitly named.

**People:**
- **Will Riker** — Engineering manager, direct and practical
- **Geordi La Forge** — Senior engineer / tech lead, hands-on
- **Data Chen** — Data engineer, brilliant and very literal
- **Deanna Troi** — People & HR lead, warm
- **Worf** — Security engineer at Borg Defense Inc. (a demanding client contact)
- **Wesley Crusher** — Junior engineer / intern
- **Guinan** — Informal mentor, asks the right questions
- **Q** — Chaotic executive at Q Ventures, unpredictable VC
- **Beverly Crusher** — Old friend, GP (personal life)
- **Isabel** — Narrator's partner
- **Lucas** — Narrator's son
- **Sofia** — Narrator's daughter
- **T'Pol** — Contact at Bajoran Technologies, met at conference
- **Neelix** — Product manager at Holodeck Labs (client)

**Companies:**
- **Starfleet Analytics** — Narrator's employer
- **Federation Systems** — Parent company
- **Holodeck Labs** — Startup client
- **Borg Defense Inc.** — Large enterprise client, demanding
- **Q Ventures** — VC firm
- **Bajoran Technologies** — Infrastructure vendor

**Projects:**
- **Warp Drive Migration** — Major infrastructure migration to LCARS Cluster Grid
- **Replicator API** — API layer (UQP / TDP protocols)
- **Holodeck Platform** — SaaS product for Holodeck Labs
- **Tricorder Dashboard** — Monitoring and analytics UI
- **Nexus Sync** — Data integration for Borg Defense
- **Temporal Archives** — Data warehouse / archival system
- **Holodeck Home** — Personal side project (local AI home assistant)

**TNG Technology Names:**
| TNG Name | Real-world analog |
|----------|------------------|
| LCARS Cluster Grid | Kubernetes |
| Universal Query Protocol (UQP) | GraphQL |
| Transporter Data Protocol (TDP) | gRPC |
| Isolinear Core Database | PostgreSQL |
| Subspace Relay Network | Kafka |
| Pattern Buffer Manifest | Terraform / Helm chart |
| Pattern Buffers | Containers / Docker |
| Automated Maintenance Protocol (AMP) | CI/CD / GitHub Actions |
| LCARS Interface Layer | React / frontend |
| Holodeck Management System | Home Assistant |
| Type-1 Isolinear Node | Raspberry Pi |
| Holographic Intelligence Module | Local LLM |
| Neural Gel Pack Index | Vector database |
| Biometric Pattern Filter | eBPF |
| Temporal Archive Operations | GitOps |
| Mission Log System | Jira |
| Starfleet Knowledge Base | Confluence / docs |
| Diagnostic Array | Monitoring / dashboards |
| Subspace API Gateway | FastAPI |
| Data Relay Transformer (DRT) | dbt |

**Conference:** Daystrom Symposium at the Daystrom Institute, Okinawa (TNG canon location)

## Entry List

| File | Language | Target length |
|------|----------|---------------|
| tng-01-work-week-review.md | English | ~15 min |
| tng-02-replicator-api-architecture.md | English | ~20 min |
| tng-03-personal-weekend.md | English | ~10 min |
| tng-04-borg-defense-kickoff.md | English | ~12 min |
| tng-05-holodeck-home-side-project.md | English | ~25 min |
| tng-06-daystrom-symposium.md | English | ~18 min |
| tng-07-sprint-23-retrospective.md | English | ~15 min |
| tng-08-mentoring-career-direction.md | English | ~12 min |
| tng-09-health-fitness-checkin.md | English | ~10 min |
| tng-10-annual-review-prep.md | English | ~20 min |
| tng-11-ddia-book-reflection.md | English | ~15 min |
| tng-nl01-weekend-werkplanning.md | Dutch | ~15 min |
| tng-de01-lcars-cluster-debugging.md | German | ~12 min |
