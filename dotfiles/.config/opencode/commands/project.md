---
description: "Create or update a tracked project in the Obsidian vault at $OBSIDIAN_VAULT/Projects/. Use to start tracking a new piece of work, or to move a project across its lifecycle (pending → progressing → completed → shelved). Status is the folder."
---

Create or update a project note in `$OBSIDIAN_VAULT/Projects/` (resolve `$OBSIDIAN_VAULT` from
the environment; default `~/vault`).

If the vault has its own `AGENTS.md`, read it first and follow its conventions. Remember:
**status is the subfolder** (`Pending`/`Progressing`/`Completed`/`Shelved`), and **do not git
commit** — leave syncing to the vault's own mechanism.

Interpret `$ARGUMENTS` and recent context to decide the action:

**Create a new project:**
1. Derive a title + tags from context (confirm the title if ambiguous).
2. Create `Projects/<Status>/<Title>.md` (default `Pending` unless context says it's already
   underway → `Progressing`) with frontmatter: `title`, `tags`, `created` = today,
   `updated` = today, `status` = matching folder.
3. Body: `> [!summary]` callout, then `## Problem`, `## Proposed Solution`, `## TODO` (use
   `- [ ]`), `## Considerations` — fill what's known, leave stubs for the rest.

**Move / update an existing project:**
1. Find the note under `Projects/**/<name>.md` (match loosely).
2. To change status: **move the file** to the new status folder, and update the `status` and
   `updated` (= today) frontmatter to match.
3. To update content: edit in place and bump `updated`.

Always report: the path, the (new) status, and whether it was created or moved.
