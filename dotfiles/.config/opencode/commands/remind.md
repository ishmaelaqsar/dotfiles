---
description: "Create a time-based reminder note in the Obsidian vault at $OBSIDIAN_VAULT/Reminders/. Use when the user says 'remind me to X (by/on/in) <when>'. Stored as due:-frontmatter so an always-on agent can later surface/fire it."
---

Create a reminder note in `$OBSIDIAN_VAULT/Reminders/` (resolve `$OBSIDIAN_VAULT` from the
environment; default `~/vault`; create the folder if missing).

Do **not** git commit — leave syncing to the vault's own mechanism.

1. **Parse the subject and the due date** from `$ARGUMENTS`:
   - Resolve relative phrasing against today's date ("tomorrow", "next Monday", "in 3 days",
     "end of month") to an absolute ISO `due:` date. Add `THH:MM` only if a time was given.
   - If the date is genuinely ambiguous, ask — a reminder with the wrong date is worse than none.
2. **Write** `Reminders/<short-slug>.md` with frontmatter:
   ```yaml
   ---
   type: reminder
   created: <today>
   due: <resolved ISO date>
   done: false
   tags: [<tag>]
   links: ["[[Related Project]]"]   # include if it ties to a known project/task
   ---
   ```
   Body: one or two lines on what to do and any context/links.
3. Do **not** delete reminders when handled later — they get `done: true`.
4. Report: the subject, the resolved due date (echo it back so the user can catch a misparse),
   and the path. Note that firing/pinging is handled by an always-on agent once one is set up;
   for now this records the reminder only.
