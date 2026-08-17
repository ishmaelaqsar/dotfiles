# Dotfiles

**Author:** Ishmael Aqsar

Configuration files, maintenance scripts, and GPG-backed secret management for my development environment.

These dotfiles are designed to work seamlessly on **macOS**, **Linux**, and inside **VS Code Dev Containers**.

---

## Bootstrap

### Option A: Automated (VS Code Dev Containers)
These dotfiles are optimized for VS Code. To have them install automatically in every container:

1. Open VS Code Settings (`Cmd+,` or `Ctrl+,`).
2. Search for **"Dotfiles"**.
3. Set **Repository** to: `your-github-username/dotfiles`
4. Set **Install Command** to: `install.sh`
5. Set **Target Path** to: `~/.dotfiles`

### Option B: Manual Installation (macOS / Linux)
To install on a fresh machine manually:

```bash
git clone https://github.com/ishmaelaqsar/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

The `install.sh` script will:
1. **Install packages** via the detected manager (brew / apt / yay / paru / pacman / dnf): `eza`, `fd`, `ripgrep`, `fzf`, `git-delta`, `zellij` (Arch/brew only — Debian and Fedora lack a package), plus [OpenCode](https://opencode.ai) and [Ghostty](https://ghostty.org) (best-effort). The list itself is data — see [The package table](#the-package-table). On Arch it first bootstraps **yay** if no AUR helper is present.
2. Symlink configuration files (`.bashrc`, `.vimrc`, etc.) to your home directory.
3. Symlink scripts from `bin/` to `$HOME/bin`.
4. Install the vendored **0xProto Nerd Font** from `general/0xProto/`.
5. **Configure GPG Agent** for SSH support and YubiKey usage (detects OS and pinentry).
6. **Install Git Hooks** to prevent committing unencrypted secrets.
7. On Linux: enable the systemd user units in `dotfiles/.config/systemd/user/`, and apply the
   GNOME settings (see [Linux desktop](#linux-desktop-gnome--arch)).

Flags and safety:

| Flag | Effect |
| :--- | :--- |
| `-n`, `--dry-run` | Print every change and make none. Reads the whole plan — packages, symlinks, git config, systemd units, GNOME keys — before anything happens. |
| `-c`, `--check` | Report what is missing or has drifted, then exit. See [Check an existing install](#check-an-existing-install). |
| `--desktop` | Run the desktop steps (GNOME settings, `wl-clipboard`) whatever the session looks like. Needed when installing over ssh, where `DISPLAY` is unset. |
| `--no-desktop` | Skip them, for a server that happens to have X libraries. |
| `-f` | Install even when a different dotfiles checkout owns `~/.dotfiles`. |
| `-h`, `--help` | Usage. |

* `./install.sh /some/dir` — **probe run**: file layout only; skips packages, git config, and all GPG keyring/agent changes. Use to test changes safely.
* It **refuses to run** if a different dotfiles checkout already owns `~/.dotfiles`; `-f` overrides. A `--dry-run` is allowed through, since it changes nothing.
* Warnings are repeated as a numbered summary at the end, so a failure in the middle of a long package run does not scroll past unread.
* After install, run `opencode auth login` once to connect a model provider.

Without a flag the desktop steps follow the session: a Wayland or X display, or `gnome-shell`
on `PATH`, means desktop.

`install.sh` needs a working `python3` for `bin/sync-dotfiles`, and stops with a clear message
when there is none. On a fresh macOS box `/usr/bin/python3` is only a stub, so run
`xcode-select --install` first.

### Check an existing install

`./install.sh --check` answers "is this machine still correctly installed?" It reads the machine,
changes nothing, and exits non-zero when something needs a repair:

```bash
./install.sh --check          # this machine
./install.sh --check /some/dir # a probe target
```

It reports:

| Checked | Treated as |
| :--- | :--- |
| Every file in `dotfiles/` is a symlink pointing back at this repo | **Failure** — missing, replaced by a real file, broken, or linked elsewhere |
| Every script in `bin/` is linked into `$HOME/bin` | **Failure** |
| The 0xProto font family is installed | **Failure** |
| `~/.gnupg/gpg-agent.conf` was written by `install.sh` | **Failure** |
| Global git identity | **Failure** — skipped on a probe target |
| The commands from the package table are on `PATH` | **Warning** — packages are best-effort, and some have no package on a given platform |

Run `./install.sh` to repair whatever it reports.

### The package table

What to install lives in `lib/packages.conf`, not in the scripts. One row per tool:

```
commands | tags | per-manager package overrides
```

* **commands** — the command names that satisfy the row, comma separated. The first is the
  identity and the default package name. A `~` prefix means no command answers to it (a shell
  script, a daemon in `sbin`, a USB driver), so `--check` reports it as unverifiable rather than
  missing.
* **tags** — `install.sh` installs a row when **all** of its tags are active. `base` is always
  active; `linux` off macOS; `desktop` on a graphical box; `arch` where `pacman` exists.
  `toolchain` is never active — those rows only map a name for a `setup-*.sh` script.
* **overrides** — `mgr=pkg` pairs. An exact manager wins, then `*=pkg`, then the first command
  name.

`lib/pkg.sh` is the driver that reads the table. To add a tool, add a row — no script changes.

### Language toolchains (opt-in, run manually)

`install.sh` stops at shell/terminal tooling. Per-language dev environments — compiler/runtime,
LSP server, debugger — are separate scripts, run only on machines that need them (idempotent):

| Script | Toolchain | LSP | Debugger |
| :--- | :--- | :--- | :--- |
| `setup-c.sh` | C/C++ (CLT / build-essential / base-devel), cmake | clangd | lldb, gdb + valgrind (Linux) |
| `setup-python.sh` | uv (manages interpreters) | ruff + basedpyright | debugpy |
| `setup-go.sh` | go | gopls | delve |
| `setup-java.sh` | sdkman → Temurin LTS, maven, gradle | jdtls (brew/AUR) | JDWP/jdb (in the JDK) |
| `setup-sbcl.sh` | SBCL + Quicklisp | none — CL uses Swank/Slynk via the editor | SBCL built-in |

These scripts share the package-manager logic in `lib/pkg.sh` and the name mappings in
[`lib/packages.conf`](#the-package-table) (the `toolchain` rows); shell init they write goes to
`~/.bashrc.d/` (marked, so cleanup can find it), never into tracked dotfiles.

### Cleanup

`./cleanup.sh` undoes an install: removes this repo's symlinks, managed `~/.bashrc.d` files,
fonts, and generated config; unsets the git config it set. `-a` also removes toolchains
(sdkman, quicklisp, uv — never `~/go`). It refuses on a machine owned by a different dotfiles
checkout, and never uninstalls system packages (it prints the list instead).

---

## Editor Configuration

* **Visual Editor:** VS Code (`code --wait`).
    * Used for git commits, merges, and complex editing when available.
* **Terminal Editor:** Vi / Vim.
    * Used for quick edits in the terminal.
    * Includes a minimal `.vimrc` for syntax highlighting and standard behavior.

These are defaults set in `.bash_profile`. To switch editors on one machine, drop a file in
`~/.bashrc.d/` (sourced last) exporting `EDITOR`, `VISUAL`, and `GIT_EDITOR` — e.g.
`export EDITOR=emacs VISUAL=emacs GIT_EDITOR=emacs`.

---

## Secret Management

This repository uses a custom GPG + YubiKey workflow to store sensitive environment variables (API keys, tokens) securely in git.

### Prerequisites
* A **YubiKey** with your PGP private keys loaded.
* Your public key exported to `dotfiles/public.asc` (auto-imported during install).

### YubiKey Required Packages
The following packages are required to interface with the YubiKey:

**Debian/Ubuntu**
```bash
sudo apt update
sudo apt install -y gnupg gnupg-agent scdaemon pcscd
```

**Arch**
```bash
sudo pacman -S --needed gnupg pcsclite ccid pcsc-tools
sudo systemctl enable --now pcscd.socket
```
`install.sh` does both steps for you: it installs `pcsclite` and `ccid` (via
`yay` if present, else `pacman`), then enables `pcscd.socket`. The commands above
are the manual equivalent.

**macOS**
```bash
brew install gnupg
```

### Initialise GnuPG
```bash
gpg -k
```

### Workflow
Add the helpers to your shell (already done if you source `.bashrc`):

```bash
source ~/.helpers
```

| Action | Command | Description |
| :--- | :--- | :--- |
| **Add Secret** | `add_secret KEY VALUE` | Encrypts `VALUE` into `.secrets` and exports `KEY` to current shell. |
| **Load Secrets** | `load_secrets` | Decrypts all secrets into environment variables (prompts for YubiKey PIN once/day). |
| **Verify** | `bin/manage-secrets verify` | Runs automatically on `git commit` to ensure no cleartext secrets are committed. |

### Example
```bash
# Store a new key (requires YubiKey touch/PIN)
add_secret OPENAI_API_KEY "sk-..."

# Load keys at start of session
load_secrets
```

---

## Terminal Agent & Second Brain

[OpenCode](https://opencode.ai) is the terminal agent. Global config ships from
`dotfiles/.config/opencode/`: behavioural rules in `AGENTS.md`, and commands for the
Obsidian-vault "second brain" — `/brief`, `/daily`, `/kb`, `/project`, `/remind`, `/report`.

The vault lives at `$OBSIDIAN_VAULT` (default `~/vault`). Shell-side companions in `.helpers`:
`jot <text>` appends to today's daily note (no LLM), `sb` opens the agent over the vault.

---

## Ghostty

Config in `dotfiles/.config/ghostty/`. The Quake-style quick terminal is **opt-in per machine**
via the untracked `config.local` (the installer enables it on macOS; Linux needs compositor
setup — see `quick-terminal.conf`). GNOME cannot host it at all, so `bin/gnome-settings` binds
Super+Return to a normal Ghostty window there instead.

---

## Linux desktop (GNOME + Arch)

### GNOME settings

`gsettings` is GNOME's counterpart to `defaults write` on macOS. `bin/gnome-settings` manages a
small **allowlist** of keys — a full `dconf dump /` is deliberately not tracked, because it is
machine-specific and unreadable in a diff.

| Command | Effect |
| :--- | :--- |
| `gnome-settings apply` | Set the managed keys. `install.sh` runs this when GNOME is detected. |
| `gnome-settings dump` | Print the current value of every managed key. |
| `gnome-settings restore` | Put the pre-dotfiles values back. `cleanup.sh` runs this. |

Managed today: Emacs key theme (GTK4 needs the gsettings key — `settings.ini` covers GTK2/3
only), dark colour scheme, 0xProto as the monospace font, Caps Lock as Control, key-repeat
rates, Night Light, fractional scaling, Ghostty as the desktop terminal, and the window keys
below. The previous values go to `~/.local/state/dotfiles/gnome-settings.json` on first apply.

### Window and workspace keys

Super stays a window-manager key on Linux, the way i3 and Hyprland use it. Terminal shortcuts
are **not** unified with macOS: `Ctrl+C` cannot be the copy key in a terminal, so Linux keeps
`ctrl+shift+…` and macOS keeps `cmd+…`.

| Key | Action |
| :--- | :--- |
| `Super+Return` | Ghostty — the i3/sway/Hyprland idiom for "terminal". |
| `Super+1…4` | Jump to that workspace. |
| `Super+Shift+1…4` | Move the focused window to that workspace. |
| `Super+Alt+Left/Right` | Previous / next workspace (a GNOME default, kept as is). |

Two GNOME defaults are displaced to make this work. `Super+N` normally switches to the Nth
**application** in the dash, so those bindings are cleared. Workspaces become **static**, four of
them (`WORKSPACES` in `bin/gnome-settings`), because a dynamic count has nothing to jump to when
the desktop is quiet. `gnome-settings restore` puts both back.

### Drop-down terminal

Ghostty's own quick terminal needs `wlr-layer-shell`, which Mutter does not implement, and on
Wayland nothing outside the shell can raise or hide another app's window. A GNOME Shell extension
is therefore the only route. `install.sh` installs
[Quake Terminal](https://extensions.gnome.org/extension/6307/quake-terminal/)
(`quake-terminal@diegodario88.github.io`), which drops down the **Ghostty** window that is already
there — so one terminal config still covers macOS and Linux.

It pulls the build that matches this machine's shell version from the extensions.gnome.org API,
with `gnome-extensions`, which ships inside gnome-shell. No extra tooling. `cleanup.sh` removes it.

After the first install: **log out and back in** (a new extension is not loaded until the shell
restarts), then set the hotkey in the extension's preferences. `F12` is the Guake convention and
collides with nothing. If you prefer ``Super+` ``, clear GNOME's `switch-group` binding first —
Mutter grabs that key before any app sees it.

The extension's own settings are **not** tracked in `gnome-settings` yet, because its schema keys
have to be read on a machine that has it installed. To track them, run
`gsettings list-recursively org.gnome.shell.extensions.quake-terminal` after setting the hotkey,
and add the keys to `SETTINGS` in `bin/gnome-settings`.

### SSH agent: gpg-agent, not GNOME's

`.bashrc` points `SSH_AUTH_SOCK` at gpg-agent, but that covers **login shells only**. Graphical
apps (VS Code and GNOME apps) read the systemd user environment, where GNOME's own agent would
otherwise claim the variable and never ask the YubiKey. Three parts fix it:

* `dotfiles/.config/environment.d/10-gpg-ssh.conf` sets `SSH_AUTH_SOCK` session-wide.
* `install.sh` enables `gpg-agent-ssh.socket`, so the agent is listening before any app asks.
* `install.sh` masks `gcr-ssh-agent` / `gnome-keyring-ssh` (whichever this GNOME version ships).

**Log out and back in** after the first install — the session environment is read at login.

HTTPS git remotes use `git-credential-libsecret` (the GNOME keyring) instead of a cleartext
`~/.git-credentials`, when the helper is present.

### systemd user units

The Linux counterpart of a macOS LaunchAgent. Drop a `*.service`, `*.timer`, or `*.socket` file
in `dotfiles/.config/systemd/user/`; `install.sh` reloads systemd and enables every unit with an
`[Install]` section, and `cleanup.sh` disables them again.

### Arch upkeep

`install.sh` installs `pacman-contrib` and enables `paccache.timer` (weekly cache trim). The
aliases wrap the rest:

| Alias | Command | Why |
| :--- | :--- | :--- |
| `pacup` | `checkupdates` | List updates without touching the sync database. |
| `pacnew` | `pacdiff` | Merge the `.pacnew` files an upgrade leaves behind silently. |
| `paccleanup` | `paccache -rk2` | Trim the package cache by hand. |
| `pacorphans` | `pacman -Qtdq` | List orphaned dependencies. |

`dotfiles/.makepkg.conf` builds AUR packages with all cores and skips package compression.
Nothing packages an AUR helper, so `install.sh` builds `yay-bin` once on a fresh Arch box —
without it, AUR-only packages (`jdtls`) are skipped.

---
