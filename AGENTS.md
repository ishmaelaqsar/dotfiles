# Repo conventions

- **This repo is public.** Never add employer-specific content: internal hostnames, company
  paths, work email addresses, or tooling that only exists on a work machine.
- **Everything under `dotfiles/` is symlinked into `$HOME`** (per-file, via `bin/sync-dotfiles`),
  and `bin/` into `~/bin` — edits here take effect on the machine immediately.
- **Secrets stay encrypted.** `.secrets` holds GPG blobs only; use `add_secret`, never paste
  cleartext. The pre-commit hook (`bin/manage-secrets verify`) enforces this.
- **Test installer changes with a probe run** — `./install.sh /tmp/probe` — never a plain
  `./install.sh` mid-session. A probe must leave the machine untouched.
- `dotfiles/.config/ghostty/config.local` is machine-local and untracked by design.
- Don't commit or push on your own initiative.
