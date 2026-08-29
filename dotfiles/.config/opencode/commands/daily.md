---
description: "Append a quick capture (note, snippet, command, thought) to today's daily note in the Obsidian vault at $OBSIDIAN_VAULT. Use as the low-friction inbox for 'jot this down' / 'log this' from any session."
---

Append a quick-capture entry to today's daily note in `$OBSIDIAN_VAULT/Daily Notes/`
(resolve `$OBSIDIAN_VAULT` from the environment; default `~/vault`).

Do **not** git commit — leave syncing to the vault's own mechanism.

1. Today's file is `Daily Notes/<YYYY-MM-DD>.md` (use the current date). Create it if missing.
2. Append the content from `$ARGUMENTS` (or the relevant snippet/command/thought from context)
   as a new top-level bullet:
   - Inline-tag the topic, for example `* #homelab <note>`.
   - Put commands/code in a fenced block under the bullet.
   - Keep it terse — this is an inbox, not a polished note.
3. If the captured item is clearly durable (reusable knowledge, a real project, a reminder),
   say so and suggest `/kb`, `/project`, or `/remind` for it. Still capture it here now.
4. Report the line(s) appended.
