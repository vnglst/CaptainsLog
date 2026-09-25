# PLAN-002: Star Trek TNG Synthetic Evaluation Test Set

## Goal

Replace the current small eval test set with a large, coherent synthetic corpus of 13 voice-memo scripts. The user reads the scripts aloud, the recordings become audio fixtures, and the transcriptions + ground truth feed all four evaluation stages.

**Theme:** The narrator is a senior engineer at Starfleet Analytics in a Star Trek TNG universe. All technology names, companies, and colleagues use TNG terminology.

---

## Source Scripts

All scripts are in [`docs/tng-eval/`](./tng-eval/). Each file contains:
1. **Raw Script** — spoken-style prose the user reads aloud (also becomes `eval/transcribe/expected/` and `eval/cleanup/input/`)
2. **Polished Version** — cleaned-up prose (becomes `eval/cleanup/expected/`, `eval/enrich/input/`, `eval/filename/input/`)
3. **Expected YAML Frontmatter** (becomes `eval/enrich/expected/`)
4. **Expected Filename** (becomes `eval/filename/expected/`)

| File | Language | Target |
|------|----------|--------|
| [tng-01-work-week-review.md](./tng-eval/tng-01-work-week-review.md) | English | ~15 min |
| [tng-02-replicator-api-architecture.md](./tng-eval/tng-02-replicator-api-architecture.md) | English | ~20 min |
| [tng-03-personal-weekend.md](./tng-eval/tng-03-personal-weekend.md) | English | ~10 min |
| [tng-04-borg-defense-kickoff.md](./tng-eval/tng-04-borg-defense-kickoff.md) | English | ~12 min |
| [tng-05-holodeck-home-side-project.md](./tng-eval/tng-05-holodeck-home-side-project.md) | English | ~25 min |
| [tng-06-daystrom-symposium.md](./tng-eval/tng-06-daystrom-symposium.md) | English | ~18 min |
| [tng-07-sprint-23-retrospective.md](./tng-eval/tng-07-sprint-23-retrospective.md) | English | ~15 min |
| [tng-08-mentoring-career-direction.md](./tng-eval/tng-08-mentoring-career-direction.md) | English | ~12 min |
| [tng-09-health-fitness-checkin.md](./tng-eval/tng-09-health-fitness-checkin.md) | English | ~10 min |
| [tng-10-annual-review-prep.md](./tng-eval/tng-10-annual-review-prep.md) | English | ~20 min |
| [tng-11-ddia-book-reflection.md](./tng-eval/tng-11-ddia-book-reflection.md) | English | ~15 min |
| [tng-nl01-weekend-werkplanning.md](./tng-eval/tng-nl01-weekend-werkplanning.md) | Dutch | ~15 min |
| [tng-de01-lcars-cluster-debugging.md](./tng-eval/tng-de01-lcars-cluster-debugging.md) | German | ~12 min |

---

## Recording Instructions

Read each **Raw Script** section aloud at a comfortable natural pace — not too fast, not too slow, as if speaking to a friend or recording a personal voice memo. Aim for the natural spoken quality: run-on sentences, self-corrections, "so anyway" transitions are all intentional. Do not read like a newsreader.

Suggested recording setup:
- Quiet room, consistent distance from microphone
- Record to `.m4a` format (iPhone Voice Memos is fine)
- Filename format: exactly the slug from the table above, e.g. `tng-01-work-week-review.m4a`
- Save to `eval/transcribe/audio/`

---

## Implementation Steps (after recording)

### Step 1: Populate transcribe/expected and cleanup/input

For each entry, copy the **Raw Script** text into two identical files:
```
eval/transcribe/expected/tng-01-work-week-review.md
eval/cleanup/input/tng-01-work-week-review.md
```

### Step 2: Populate cleanup/expected, enrich/input, filename/input

For each entry, copy the **Polished Version** text into three identical files:
```
eval/cleanup/expected/tng-01-work-week-review.md
eval/enrich/input/tng-01-work-week-review.md
eval/filename/input/tng-01-work-week-review.md
```

### Step 3: Populate enrich/expected

For each entry, copy the **Expected YAML Frontmatter** block (including `---` delimiters) into:
```
eval/enrich/expected/tng-01-work-week-review.md
```

### Step 4: Populate filename/expected

For each entry, copy the **Expected Filename** (the one-line `.md` filename) into:
```
eval/filename/expected/tng-01-work-week-review.md
```

### Step 5: Remove old eval cases

Delete the existing files from:
- `eval/transcribe/expected/`
- `eval/cleanup/input/` and `eval/cleanup/expected/`
- `eval/enrich/input/` and `eval/enrich/expected/`
- `eval/filename/input/` and `eval/filename/expected/`
- `eval/transcribe/audio/` (old recordings)

Do not archive — delete.

---

## Feature Coverage Matrix

| Feature | Entries |
|---------|---------|
| English cleanup: filler words, run-ons | 01, 04, 05, 06, 07 |
| Dutch speech patterns | NL-01 |
| German speech patterns | DE-01 |
| Technical jargon (TNG tech) | 02, 05, 11, DE-01 |
| Personal / emotional tone | 03, 08, 09 |
| Enrich: work-only | 01, 02, 07, DE-01 |
| Enrich: personal-only | 03, 09 |
| Enrich: mixed work + personal | 04, NL-01 |
| Enrich: side-project | 05 |
| Enrich: work + personal-development | 08, 10, 11 |
| Enrich: travel | 06 |
| Enrich: health | 09 |
| Filename: single dominant topic | 02, 07, 09, DE-01 |
| Filename: multi-topic (distillation needed) | 01, 04, 10, NL-01 |
| Filename: long entry | 05, 06, 10 |
| Multiple persons | 01, 04, 07, 08, 10 |
| Multiple projects | 01, 04, 07, 10 |
| Multiple companies | 02, 04, 07 |
| TNG technology entities | 02, 05, 06, 11, DE-01 |
| Book / event entities | 06, 08, 11 |

---

## TNG Universe Reference

See [`docs/tng-eval/README.md`](./tng-eval/README.md) for the full universe: characters, companies, projects, and the complete TNG-to-real-world technology mapping.

Key facts:
- Narrator's employer: **Starfleet Analytics** (parent: **Federation Systems**)
- Manager: **Will Riker**; tech lead: **Geordi La Forge**; data engineer: **Data Chen**
- Enterprise client: **Borg Defense Inc.** (integration lead: Worf)
- Startup client: **Holodeck Labs** (PM: Neelix)
- Narrator's partner: **Isabel**; children: **Lucas** (birds), **Sofia**
- Conference: **Daystrom Symposium** at Daystrom Institute, Okinawa
- Side project: **Holodeck Home** (local AI home assistant)
