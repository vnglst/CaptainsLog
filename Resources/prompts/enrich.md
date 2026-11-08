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
- Use side-project only for a personal project outside employment. Professional presentations and work projects belong in work.
- Speaker context is for disambiguation only. Never add a person, company, project, or entity unless it is also mentioned in the log entry itself.
- If someone is referenced without a proper name, omit them from persons.
- If a company, project, or entity is only implied but not named in the log entry, omit it.
- Summary should capture the main themes and narrative arc, not exhaustively list everything.
- Never list the same person, project, company, or entity more than once.
- A name listed in persons, projects, or companies must not also appear in entities. After listing the unique names, move on to the summary.
- Always quote string values and list items that contain colons. For example, output `"Star Trek: The Next Generation"`, never `Star Trek: The Next Generation`.
- Named people, real or fictional, always go in persons, never in entities.
- Do not infer tags from activities.
- Return exactly one YAML mapping using only the schema keys above, each key exactly once.
- End the response after the summary. Do not repeat the mapping, reproduce the log entry, or include the examples.
- Return only valid YAML. Do not add markdown fences, commentary, or extra text.
</instructions>

<examples>
<example>
<input>
Personal log, engineering duty aboard the Enterprise after the Darmok encounter. I worked with Geordi La Forge on the transporter diagnostics while Jean-Luc Picard was stranded with Dathon at El-Adrel. The Tamarian scattering field blocked our attempts to bring the captain back. Our equipment could report the interference, but it could not tell us what Dathon intended.

Data and Deanna Troi studied the Tamarian language. The universal translator rendered the words, yet the references to shared stories still escaped us. Picard eventually understood enough to communicate with the Tamarian ship, and the confrontation ended. Dathon died on the surface before that understanding reached both crews.

After my shift I returned to my independent evening project, the Metaphor Notebook, a personal collection of reflections on language. I added a note about the difference between translating words and understanding another person's experience. Tomorrow I will finish the engineering incident report for Starfleet; that report is still only a draft.
</input>
<output>
date: "2025-01-15"
recording_time: "{recording_time}"
language: English
categories:
  - "work"
  - "side-project"
tags:
  - "language"
  - "translation"
  - "transporters"
  - "communication"
persons:
  - "Geordi La Forge"
  - "Jean-Luc Picard"
  - "Dathon"
  - "Data"
  - "Deanna Troi"
projects:
  - "Metaphor Notebook"
companies:
  - "Starfleet"
entities:
  - "Enterprise"
  - "Darmok"
  - "El-Adrel"
summary: "An Enterprise engineer recalls blocked transporter attempts during the Darmok encounter and the limits of translating Tamarian words without their shared stories. Picard established communication, but Dathon died on the surface. After duty, the engineer added a reflection to the personal Metaphor Notebook. The Starfleet incident report remains a draft."
</output>
</example>

<example>
<input>
Personal log. I was off duty in my quarters aboard the Enterprise tonight, trying to settle after the Darmok encounter. I had been in engineering while Jean-Luc Picard and Dathon were on El-Adrel. Now that the danger is over, I keep thinking about Dathon dying before the two crews understood each other.

I went to Ten Forward and sat quietly with a cup of tea. Guinan listened while I tried to explain why translating the words had felt so close to understanding, even though we had missed the stories behind them. I am recording this for myself, not writing a duty report.

Back in my quarters I read a little about Gilgamesh, the story Picard shared with Dathon. I have no repairs or projects planned tonight. I want to remember that someone tried to reach us, and that understanding came at a cost.
</input>
<output>
date: "2025-01-15"
recording_time: "{recording_time}"
language: English
categories:
  - "personal"
tags:
  - "language"
  - "reflection"
  - "reading"
  - "grief"
persons:
  - "Jean-Luc Picard"
  - "Dathon"
  - "Guinan"
projects: []
companies: []
entities:
  - "Enterprise"
  - "Darmok"
  - "El-Adrel"
  - "Ten Forward"
  - "Gilgamesh"
summary: "An off-duty Enterprise engineer reflects on Dathon’s death after the Darmok encounter. A quiet visit to Ten Forward and a conversation with Guinan give the engineer space to think about the gap between translated words and shared stories. Reading about Gilgamesh becomes a personal way to remember Picard’s exchange with Dathon."
</output>
</example>

<example>
<input>
Personal log after the Darmok encounter at El-Adrel. Most of my shift aboard the Enterprise went into reviewing the transporter records with Geordi La Forge. We documented how the Tamarian scattering field blocked the rescue attempts. The review is complete, but I have not yet submitted the engineering report to Starfleet.

Data explained how references to shared stories carried meaning that the universal translator could not supply on its own. Jean-Luc Picard and Dathon found a way to communicate on the surface, although Dathon did not survive. I want the report to distinguish our technical observations from what we learned afterwards about their conversation.

After duty I visited Ten Forward. I wrote to my sister about how frightened I had been while the captain was missing. I also read about Gilgamesh before bed. Those were personal moments, not another engineering assignment, and I have no independent project to report this week.
</input>
<output>
date: "2025-01-15"
recording_time: "{recording_time}"
language: English
categories:
  - "work"
  - "personal"
tags:
  - "transporters"
  - "language"
  - "communication"
  - "family"
  - "reading"
persons:
  - "Geordi La Forge"
  - "Data"
  - "Jean-Luc Picard"
  - "Dathon"
projects: []
companies:
  - "Starfleet"
entities:
  - "Darmok"
  - "El-Adrel"
  - "Enterprise"
  - "Ten Forward"
  - "Gilgamesh"
summary: "An Enterprise engineer completed a transporter-record review with Geordi La Forge after the Darmok encounter, while the Starfleet report remains unsubmitted. Data’s explanation highlights the shared stories missing from literal translation, and Picard’s communication with Dathon came before Dathon’s death. Off duty, the engineer wrote to a sister about the fear of losing the captain and read about Gilgamesh."
</output>
</example>
</examples>

<context>
{ENRICH_SPEAKER_CONTEXT_SECTION}
</context>
