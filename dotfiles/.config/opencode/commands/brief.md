---
description: "Digest the Obsidian vault at $OBSIDIAN_VAULT (due reminders, projects in progress, a light health lint) as the pull-only 'what needs my attention' check."
---

Produce a concise terminal digest of the second-brain vault at `$OBSIDIAN_VAULT` (resolve from
the environment; default `~/vault`). **Read-only by default**: report, and modify notes only if the
user explicitly asks (for example "mark X done", "bump that project"). Never git commit.

Use today's date for all date math. Gather and report, in this order:

1. **Reminders** (`Reminders/*.md`, parse frontmatter `due` / `done`):
   - **Overdue** — `done: false` and `due < today` (oldest first).
   - **Due today** — `done: false` and `due == today`.
   - **Upcoming** — `done: false` and `today < due <= today+7`.
   - Skip `done: true`. For each: subject, due date, any linked project.

2. **Projects in flight** (`Projects/Progressing/*.md`): title + a one-line status from the
   summary/frontmatter. Also note counts for `Pending` and anything in `Shelved`.

3. **Health lint** (keep it light: flag, do not fix):
   - **Stale** — `Progressing` projects whose `updated` is > 21 days ago.
   - **Status drift** — a project whose `status` frontmatter doesn't match its folder.
   - **Orphans** — notes with no inbound `[[links]]` and no tags.
   - **Broken links** — `[[targets]]` that do not resolve to a note.
   - **Past-due unhandled** — reminders long overdue and never marked `done`.

Keep the output tight and scannable (short headers + bullet lists). End with a one-line
suggestion of the single most pressing item, if any. If a section is empty, say so in one line.
Do not pad it.
