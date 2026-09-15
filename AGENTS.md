# Repo conventions

- **This repo is public.** Never add employer content: internal hostnames, company paths, work
  email addresses, or tools that exist only on a work machine.
- **Every file under `dotfiles/` is symlinked into `$HOME`**, per file, by `lib/sync-dotfiles`,
  which `dotfiles sync` calls. `bin/` is symlinked into `~/bin`. An edit in the checkout is live
  on the machine at once.
- **Secrets stay encrypted.** `.secrets` holds GPG blobs only. Use `add_secret`, never paste
  cleartext. The pre-commit hook runs `bin/manage-secrets verify`, and the pre-push hook scans
  every outgoing commit for a cleartext secret.
- **Test an installer change with a probe run**: `./install.sh /tmp/probe`, never a plain
  `./install.sh` mid-session. A probe must leave the machine untouched. Then
  `./install.sh --check /tmp/probe` must pass.
- **To add or rename a package, edit `lib/packages.conf`**: one row per tool, selected by tag.
  `lib/pkg.sh` is the driver and needs no change. Keep the row's first command name the one that
  lands on `PATH`, or mark it `~` when none does.
- `dotfiles/.config/ghostty/config.local` and `~/.config/hypr/local.conf` are machine-local and
  untracked by design.
- The build notes in `docs/` and the templates in `general/` stay generic. A host name, an
  address, or a path that is yours becomes an angle-bracket placeholder, such as `<your-email>`.
- Do not commit or push on your own initiative.

## Comments and documentation

Write in Simplified Technical English (ASD-STE100) and follow the
[Google developer documentation style guide](https://developers.google.com/style): short
sentences, active voice, present tense, "you" for the reader, sentence-case headings, "for
example" instead of "e.g.", no "simply" or "just", no direction words such as "above". British
spelling in prose. Identifiers and quoted output keep theirs.

- Describe the current state only. No past state, no migration story, no dates, no "now",
  "still", "no longer", "replaced", or "used to". History goes in the commit body. A comment that
  no longer matches the code is worse than none: delete it.
- A comment explains why. Delete a comment that restates the code, names the option or glob under
  it, or labels a block with the name of the thing in it. No comment is better than a useless one.
- One fact has one home. A code comment holds the reason. The README holds the map and names the
  file. Do not restate a fact in a second file or a second section.
- No waffle. No hedges, filler adverbs ("quickly", "actually", "safely"), figurative language,
  rhetorical questions, shouting capitals, emoji, or banners that name the next line.
- Generic by default. Add a machine, person, or version detail only when the reader needs it to
  act. Examples use placeholders.
- Agent prompts (the opencode `AGENTS.md` and `commands/*.md`) follow the same rules in their
  prose. Keep every instruction's meaning.
