---
description: "Write up the current session's investigation/analysis as a point-in-time report note in the Obsidian vault's Reports/ folder (dated, shareable). Use when the user says 'write this up', 'put this in my second brain as a report', 'turn this into a report', or wants a finished analysis captured as a note rather than an evergreen KB entry."
---

Capture the current investigation/analysis as a **report** note in the Obsidian vault at
`$OBSIDIAN_VAULT` (resolve from the environment; default `~/vault`). A report is a
*point-in-time* findings document (what we learned on date X), distinct from `/kb` (evergreen
reference) and `/project` (tracked work).

If the vault has its own `AGENTS.md`, read it first and follow its conventions (tags, backlinks,
lint rules).

1. **Decide the subject & title** from `$ARGUMENTS` if given, else from the recent conversation
   (the investigation just completed).
2. **Target** `Reports/YYYY-MM-DD <Title>.md` (today's date; create the `Reports/` folder if
   missing). If a report on the same subject from today already exists, offer to extend it.
3. **Write the note**, lint-clean, with frontmatter:

   ```yaml
   ---
   title: <Human Title>
   tags: [<tag>, <tag>]
   created: YYYY-MM-DD
   updated: YYYY-MM-DD
   type: report
   ---
   ```

   Body structure (adapt to the subject — don't pad):
   - Lead with a `> [!summary]` callout: the finding, the cause, the recommendation, in a few lines.
   - **Headline numbers** as a table where the analysis is quantitative.
   - Numbered/titled **findings** sections; use tables for data and `> [!note]`/`> [!warning]`
     callouts for caveats and ruled-out hypotheses.
   - A **recommendations / what-to-do** list.
   - A **Source & method** footer: where the data came from, how it was computed, and any
     reproduction caveats — so the report is auditable later.
4. Cross-link related vault notes with `[[…]]` and inline `#tags`. Prefer linking over duplicating.
5. **Do not git commit** — leave syncing to the vault's own mechanism. Keep markdown lint-clean
   (one H1, blank lines around headings/lists, frontmatter at the very top).
6. Report the path written and the tags used.

Honesty rules: report outcomes faithfully — state what was ruled out and why, flag any figure you
could not reproduce exactly, and keep claims tied to the data you actually pulled.
