# Repo conventions

- **This repo is public.** Never add employer-specific content: internal hostnames, company
  paths, work email addresses, or tooling that only exists on a work machine.
- **Everything under `dotfiles/` is symlinked into `$HOME`** (per-file, via `lib/sync-dotfiles`, which `dotfiles sync` calls),
  and `bin/` into `~/bin` — edits here take effect on the machine immediately.
- **Secrets stay encrypted.** `.secrets` holds GPG blobs only; use `add_secret`, never paste
  cleartext. The pre-commit hook (`bin/manage-secrets verify`) enforces this.
- **Test installer changes with a probe run** — `./install.sh /tmp/probe` — never a plain
  `./install.sh` mid-session. A probe must leave the machine untouched. Then
  `./install.sh --check /tmp/probe` must pass.
- **To add or rename a package, edit `lib/packages.conf`** — one row per tool, selected by tag.
  `lib/pkg.sh` is the driver and needs no change. Keep the row's first command name the one that
  lands on `PATH`, or mark it `~` when none does.
- `dotfiles/.config/ghostty/config.local` and `~/.config/hypr/local.conf` are machine-local and
  untracked by design.
- Don't commit or push on your own initiative.
