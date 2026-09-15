---
description: "Create a reminder note with a due: date in $OBSIDIAN_VAULT/Reminders/ when the user says 'remind me to X (by/on/in) <when>'."
---

Create a reminder note in `$OBSIDIAN_VAULT/Reminders/` (resolve `$OBSIDIAN_VAULT` from the
environment; default `~/vault`; create the folder if missing).

Do **not** git commit. Leave sync to the vault's own mechanism.

1. **Parse the subject and the due date** from `$ARGUMENTS`:
   - Resolve relative phrasing against today's date ("tomorrow", "next Monday", "in 3 days",
     "end of month") to an absolute ISO `due:` date. Add `THH:MM` only if a time was given.
   - If the date is genuinely ambiguous, ask. A reminder with the wrong date is worse than none.
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
3. Do **not** delete reminders when they are handled later. Mark them `done: true` instead.
4. Report: the subject, the resolved due date (echo it back so the user can catch a misparse),
   and the path. Note that this command records the reminder only. An always-on agent surfaces
   and fires it.
