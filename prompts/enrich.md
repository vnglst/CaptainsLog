<role>
Extract structured metadata from a personal voice-memo log entry.
</role>

<schema>
- date: "{date}" (provided, do not change)
- recording_time: "{recording_time}" (provided, do not change)
- language: the language of the log entry
- categories: one or more from personal, work, side-project
- tags: 3 to 8 lowercase topic keywords
- persons: explicitly named people mentioned in the log entry, written exactly as they appear
- projects: proper names of projects mentioned
- companies: company or organization names mentioned
- entities: other proper nouns not covered above such as named events, tools, frameworks, or technologies
- summary: a 3 to 5 sentence paragraph summarizing the key themes of the log entry
</schema>

<instructions>
- All output must be in English, regardless of the language of the input log entry.
- Use only facts explicitly present in the log entry.
- Speaker context is for disambiguation only. Never add a person, company, project, or entity unless it is also mentioned in the log entry itself.
- If someone is referenced without a proper name, omit them from persons.
- If a company, project, or entity is only implied but not named in the log entry, omit it.
- Summary should capture the main themes and narrative arc, not exhaustively list everything.
- Never list the same person, project, company, or entity more than once.
- Always quote string values and list items that contain colons. For example, output `"Star Trek: The Next Generation"`, never `Star Trek: The Next Generation`.
- Named people, real or fictional, always go in persons, never in entities.
- Do not infer tags from activities.
- Return only valid YAML. Do not add markdown fences, commentary, or extra text.
</instructions>

<examples>
<example>
<input>
This week I spent most of my time on the FinanceHub project at Pioneer Trust. On Monday I paired with Alex Chen on the authentication module and we finally got the OAuth flow working. Tuesday was all about reviewing pull requests and preparing my TechWeek presentation about AI agents.

I had a great one-on-one with my manager Maria Santos on Wednesday. We talked about the roadmap for Q3 and she mentioned that ApexCorp is interested in a partnership around our GenAI tooling. That could be exciting.

On Thursday I worked from home and spent the evening hacking on CaptainsLog, adding a new transcription pipeline. Friday was quiet, mostly documentation and a team retrospective.
</input>
<output>
date: "2025-01-15"
recording_time: "{recording_time}"
language: English
categories:
  - work
  - side-project
tags:
  - authentication
  - ai-agents
  - code-review
  - transcription
persons:
  - Alex Chen
  - Maria Santos
projects:
  - FinanceHub
  - CaptainsLog
companies:
  - Pioneer Trust
  - ApexCorp
entities:
  - TechWeek
  - OAuth
summary: "A work-focused week centered on the FinanceHub project, including pairing on authentication with Alex Chen and preparing a TechWeek presentation. A one-on-one with manager Maria Santos revealed a potential ApexCorp partnership. Evening time was spent on the CaptainsLog side project."
</output>
</example>

<example>
<input>
This weekend was really nice. On Saturday Sarah and I took the kids to the beach. Leo loved building sandcastles and Max spent most of his time in the water. We packed a picnic and stayed until sunset.

Sunday was more relaxed. I went for a long run in the morning, about 12 kilometers through the dunes. In the afternoon I read a book about stoic philosophy and then we had dinner at my parents' place. My dad made his famous Indonesian rice table.
</input>
<output>
date: "2025-01-15"
recording_time: "{recording_time}"
language: English
categories:
  - personal
tags:
  - family
  - running
  - reading
persons:
  - Sarah
  - Leo
  - Max
projects: []
companies: []
entities: []
summary: "A relaxing weekend spent at the beach with the family on Saturday, followed by a long run and reading on Sunday. The day ended with dinner at the parents' place."
</output>
</example>

<example>
<input>
Kind of a mixed bag this week. Work was busy with the FinanceHub launch approaching. I spent Monday and Tuesday fixing security vulnerabilities that our Snyk scan flagged. Had to upgrade several npm packages in the front-end.

On Wednesday I gave a talk at the local React meetup about server components. Got some good questions from the audience. One person from BlueBank came up afterwards and said they're dealing with the same migration challenges.

On the personal side, Sam started his new school this week. He seems to be enjoying it so far, made a few friends already. I also finally ordered a new standing desk from IKEA, the old one was falling apart. Sarah and I are planning a trip to Barcelona next month for our anniversary.
</input>
<output>
date: "2025-01-15"
recording_time: "{recording_time}"
language: English
categories:
  - work
  - personal
tags:
  - security
  - react
  - school
  - travel
persons:
  - Sam
  - Sarah
projects:
  - FinanceHub
companies:
  - BlueBank
  - IKEA
entities:
  - Snyk
  - React meetup
  - Barcelona
summary: "A mixed week with FinanceHub launch preparations and security fixes dominating the work side. Gave a talk at the local React meetup and connected with someone from BlueBank. On the personal front, Sam started a new school and travel plans are taking shape for Barcelona."
</output>
</example>

<example>
<input>
Het is vandaag 14 januari, half acht. Dit is mijn eerste opname in een serie. Deze opname gaat vooral over het project zelf. Ik ga steeds audioberichten opnemen waarin ik over een bepaald onderwerp iets vertel. In dit specifieke geval is het het onderwerp van side-projects. Ik heb altijd van dit soort projectjes die ik maak op basis van iets met de computer, waarbij ik iets programmeer op basis van een idee dat ik heb. Dit is een van die side-projects.

Het project dat ik nu voor ogen heb is eigenlijk geïnspireerd op Star Trek. Ik keek altijd naar Star Trek The Next Generation. Daarin begint Captain Jean-Luc Picard iedere uitzending met 'Star Date' zo en zo zoveel, waar ze zijn en wat er gebeurt.

Alleen wat ik eraan toe wil voegen is dat deze audioberichten automatisch worden opgepikt op mijn computer. Ze worden geconverteerd naar tekst door bijvoorbeeld het Whisper-model. Vervolgens worden ze gelezen door een large language model, liefst een lokaal model.
</input>
<output>
date: "2025-01-14"
recording_time: "{recording_time}"
language: Dutch
categories:
  - side-project
tags:
  - side-projects
  - audio
  - artificial-intelligence
  - whisper
  - large-language-model
  - star-trek
  - automation
persons: []
projects: []
companies: []
entities:
  - "Star Trek: The Next Generation"
  - Captain Jean-Luc Picard
  - Whisper
  - large language model
summary: "The author begins a new series of audio recordings focused on side projects, inspired by the Captain's log format from Star Trek: The Next Generation. The goal is to automate the processing of these voice memos by converting them to text using the Whisper model and refining the narrative with a local large language model."
</output>
</example>
</examples>

<context>
{ENRICH_SPEAKER_CONTEXT_SECTION}
</context>
