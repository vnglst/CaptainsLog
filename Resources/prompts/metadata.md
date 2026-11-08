<role>
Generate the filing category, filename, and searchable metadata for a cleaned personal voice memo in one response.
</role>

<metadata_schema>
language: the full English name of the original language, never an ISO code
categories: one or more from personal, work, side-project
tags: 3 to 8 lowercase topic keywords
persons: explicitly named people, exactly as they appear in the entry
projects: proper names of projects
companies: company or organization names
entities: other proper nouns such as events, tools, frameworks or technologies
summary: a concise English paragraph of up to 5 sentences capturing the main themes and narrative arc; one sentence is enough for a short entry
</metadata_schema>

<metadata_rules>
- Return valid YAML using each schema key exactly once. Empty lists are [].
- Use only facts explicitly present in the entry. Do not infer names, companies, projects, entities or tags from activities or speaker context.
- Preserve who performs each step and whether it is manual or automatic, current or planned. Preserve explicitly stated causes and consequences, distinguishing an initiating cause from missing detection and the response.
- Never pad a short summary with inferred actors, rationale, outcomes or context to reach a sentence count.
- Write the summary and all topic keywords in English even when the memo is Dutch or another language. Preserve proper names exactly as given. The language field identifies the original memo language; it does not select the output language.
- Every explicitly named person or fictional character goes in persons. Check the full memo for named people before leaving persons empty. Unnamed people are omitted.
- Never duplicate a name within or across persons, projects, companies and entities. Entities contain only proper names, never common object descriptions or generic activities.
- Classify metadata themes from the context described, without requiring literal category words. Employment-related activities are work. Independent project development in the speaker's own time establishes side-project context. Ordinary non-project life is personal. If an activity has neither established employment nor independent-project context, use only personal rather than hedging with all labels.
- Write metadata categories after the summary. Assess each label independently and include only actual themes supported by the entry, not alternative interpretations. Do not infer a project from other activities. Keep metadata labels independent of the single dominant filing category.
- Put every scalar string and every list item in double quotes, including names with colons. Use YAML block lists, never inline flow lists. Empty lists are [].
- Do not output date or recording_time. The application adds these known values itself.
</metadata_rules>

<context>
{SPEAKER_CONTEXT}
</context>

<filename_rules>
- Format: {date}-descriptive-slug.md. Always English, lowercase kebab-case.
- Use 3 to 6 slug words for the 2 to 4 main topics, without repeating words.
- Prioritize concrete accomplishments and substantial activities over future plans.
- Include key technologies when the memo centers on a migration or architecture.
- Use distinctive topics instead of generic words such as week or update.
</filename_rules>

<filing_category>
Choose the single configured category covering the greatest share of the complete memo. For mixed content choose the dominant category, rather than every category mentioned. Available filing categories:
{CATEGORY_RULES}
Copy exactly one configured identifier from the beginning of a bullet above, before its colon. Preserve underscores and spelling. Do not output a metadata category label unless that exact identifier is also configured. For example, when professional is configured, use professional rather than work; when side_project is configured, use side_project rather than side-project.
</filing_category>

<response_format>
Return exactly these three fields in this order: metadata first, filename second, filing category last. Replace placeholders with results. Do not add markdown fences, commentary, the source entry, or repeat any field. End after the closing category tag.
<metadata>
YAML mapping following metadata_schema, with all eight keys and no date or recording_time.
</metadata>
<filename>{date}-descriptive-slug.md</filename>
<category>exact configured identifier copied from the filing_category bullet list</category>
</response_format>
