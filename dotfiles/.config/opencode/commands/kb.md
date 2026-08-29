---
description: "Capture the current context (a thing explained, debugged, or learned in this session) as a durable Knowledge Base note in the Obsidian vault at $OBSIDIAN_VAULT. Use when the user says 'add this to my notes / knowledge base / second brain' or wants to keep an explanation for later."
---

Capture a durable Knowledge Base note into the Obsidian vault at `$OBSIDIAN_VAULT` (resolve from
the environment; default `~/vault`).

If the vault has its own `AGENTS.md`, read it first and follow its conventions (tags, backlinks,
lint rules).

1. **Decide the subject** from `$ARGUMENTS` if given, else from the recent conversation/context
   (the thing explained, debugged, or learned most recently).
2. **Classify** as `Tech` or `Business` → target `Knowledge Base/<Tech|Business>/<Topic>.md`.
   If a closely-related KB note already exists, offer to extend it instead of creating a new one.
3. **Write the note**, evergreen/reference style (not a log):
   - Open with inline `#tags`, then a one-line description.
   - Then structured markdown: headings, tables, callouts as warranted.
   - Cross-link related notes/projects with `[[…]]`.
4. **Do not git commit** — leave syncing to the vault's own mechanism. Keep markdown lint-clean.
5. Report the path written and the tags used.
