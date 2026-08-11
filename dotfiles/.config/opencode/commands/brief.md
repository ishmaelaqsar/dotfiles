---
description: "Digest of the Obsidian vault at $OBSIDIAN_VAULT: due/overdue reminders, in-progress projects, and a light health lint (stale items, orphans, broken links). Use as the pull-only 'what needs my attention' check for the terminal second brain."
---

Produce a concise terminal digest of the second-brain vault at `$OBSIDIAN_VAULT` (resolve from
the environment; default `~/vault`). **Read-only by default** — report; only modify notes if the
user explicitly asks (e.g. "mark X done", "bump that project"). Never git commit.

Use today's date for all date math. Gather and report, in this order:

1. **Reminders** (`Reminders/*.md`, parse frontmatter `due` / `done`):
   - **Overdue** — `done: false` and `due < today` (oldest first).
   - **Due today** — `done: false` and `due == today`.
   - **Upcoming** — `done: false` and `today < due <= today+7`.
   - Skip `done: true`. For each: subject, due date, any linked project.

2. **Projects in flight** (`Projects/Progressing/*.md`): title + a one-line status from the
   summary/frontmatter. Also note counts for `Pending` and anything in `Shelved`.

3. **Health lint** (keep it light — flag, don't fix):
   - **Stale** — `Progressing` projects whose `updated` is > 21 days ago.
   - **Status drift** — a project whose `status` frontmatter doesn't match its folder.
   - **Orphans** — notes with no inbound `[[links]]` and no tags.
   - **Broken links** — `[[targets]]` that don't resolve to a note.
   - **Past-due unhandled** — reminders long overdue and never marked `done`.

Keep the output tight and scannable (short headers + bullet lists). End with a one-line
suggestion of the single most pressing item, if any. If a section is empty, say so in one line
rather than padding.
