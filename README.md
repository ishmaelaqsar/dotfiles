# Dotfiles

**Author:** Ishmael Aqsar

Configuration files, maintenance scripts, and GPG-encrypted secrets for my development
environment. They work on **macOS**, **Linux**, and inside **VS Code Dev Containers**.

---

## Bootstrap

### Option A: VS Code Dev Containers

VS Code can install the dotfiles in every container. Open Settings (`Cmd+,` or `Ctrl+,`), search
for **Dotfiles**, and set three fields:

1. **Repository** — `your-github-username/dotfiles`
2. **Install Command** — `install.sh`
3. **Target Path** — `~/.dotfiles`

### Option B: macOS and Linux

Install on a fresh machine:

```bash
git clone https://github.com/ishmaelaqsar/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` does these steps:

1. **Install the packages** with the manager it finds (brew, apt, yay, paru, pacman or dnf):
   `eza`, `fd`, `ripgrep`, `fzf`, `git-delta`, `lazygit`, `tmux` and more. The list is data —
   see [The package table](#the-package-table). Some packages are best-effort: `lazygit` is not in
   Fedora's base repos, and `lazydocker` is not in Debian's. It also installs
   [OpenCode](https://opencode.ai) and [Ghostty](https://ghostty.org), which can fail without
   stopping the run. On Arch it builds **yay** first when no AUR helper exists.
2. **Link the config files** (`.bashrc`, `.vimrc`, and the rest) into your home directory.
3. **Link the scripts** in `bin/` into `$HOME/bin`.
4. **Install the 0xProto Nerd Font** from `general/0xProto/`.
5. **Configure global git**: the identity, the global ignore and attributes files, and **delta**
   as the diff pager. It sets the pager keys only when `delta` is on `PATH`, because a `core.pager`
   that is absent breaks every `git diff`. On Linux it also picks the libsecret credential helper
   when one exists.
6. **Configure the GPG agent** for SSH and the YubiKey. It detects the OS and the pinentry
   program.
7. **Install the git hook** that keeps cleartext secrets out of a commit.
8. On Linux, enable the systemd user units in `dotfiles/.config/systemd/user/`, and apply the
   GNOME settings. See [Linux desktop](#linux-desktop-gnome--arch).

Flags:

| Flag | Effect |
| :--- | :--- |
| `-n`, `--dry-run` | Print every change, and make none. Read the whole plan first: packages, symlinks, git config, systemd units and GNOME keys. |
| `-c`, `--check` | Report what is missing or has drifted, then exit. See [Check an existing install](#check-an-existing-install). |
| `--desktop` | Run the desktop steps whatever the session looks like (GNOME settings, `wl-clipboard`). Use it over ssh, where `DISPLAY` is not set. |
| `--no-desktop` | Skip those steps, for a server that has X libraries. |
| `-f` | Install even when a different dotfiles checkout owns `~/.dotfiles`. |
| `-h`, `--help` | Print the usage text. |

Without a flag, the session decides: a Wayland or X display, or `gnome-shell` on `PATH`, means a
desktop.

Safety:

* `./install.sh /some/dir` is a **probe run**. It writes the file layout only. It skips the
  packages, the git config, and every GPG keyring change. Use it to test a change.
* The script **refuses to run** when a different dotfiles checkout owns `~/.dotfiles`. `-f`
  overrides the guard. A dry run passes the guard, because it changes nothing.
* It repeats every warning as a numbered summary at the end. A failure in the middle of a long
  package run then does not scroll past unread.
* It needs a working `python3` for `lib/sync-dotfiles`, and stops with a clear message when there
  is none. On a fresh macOS machine `/usr/bin/python3` is only a stub, so run
  `xcode-select --install` first.
* After the install, run `opencode auth login` once to connect a model provider.

### Check an existing install

`./install.sh --check` answers one question: is this machine still correctly installed? It reads
the machine, changes nothing, and exits non-zero when a repair is necessary.

```bash
./install.sh --check           # this machine
./install.sh --check /some/dir # a probe target
dotfiles doctor                # the same report, by its shorter name
```

| Checked | Result |
| :--- | :--- |
| Every file in `dotfiles/` is a symlink back to this repo | **Failure** — missing, a real file, broken, or linked elsewhere |
| Every script in `bin/` is linked into `$HOME/bin` | **Failure** |
| The 0xProto font family is installed | **Failure** |
| `install.sh` wrote `~/.gnupg/gpg-agent.conf` | **Failure** |
| The global git identity, and the delta pager keys when `delta` is installed | **Failure** — skipped on a probe target |
| The commands in the package table are on `PATH` | **Warning** — packages are best-effort, and some have no package on a platform |

Run `./install.sh` to repair what it reports.

### The package table

`lib/packages.conf` holds what to install. The scripts hold no list. One row per tool:

```
commands | tags | per-manager package overrides
```

* **commands** — the command names that satisfy the row, separated by commas. The first name is
  the identity, and the default package name. A `~` prefix means that no command answers to the
  row: a shell script, a daemon in `sbin`, or a USB driver. `--check` then reports the row as
  unverifiable, not missing.
* **tags** — `install.sh` installs a row when **all** of its tags are active. `base` is always
  active. `linux` is active off macOS, `desktop` on a graphical machine, and `arch` where `pacman`
  exists. `toolchain` is never active; those rows only map a name for a `setup-*.sh` script.
* **overrides** — `mgr=pkg` pairs. An exact manager wins first, then `*=pkg`, then the first
  command name.

`lib/pkg.sh` reads the table. To add a tool, add a row. No script changes.

### Language toolchains

`install.sh` stops at the shell and terminal tools. Each language environment is a separate
script: the compiler or runtime, the LSP server, and the debugger. Run them by hand, only on a
machine that needs them. They are idempotent.

| Script | Toolchain | LSP | Debugger |
| :--- | :--- | :--- | :--- |
| `setup-c.sh` | C/C++ (CLT / build-essential / base-devel), cmake | clangd | lldb, gdb + valgrind (Linux) |
| `setup-python.sh` | uv (manages interpreters) | ruff + basedpyright | debugpy |
| `setup-go.sh` | go | gopls | delve |
| `setup-java.sh` | sdkman → Temurin LTS, maven, gradle | jdtls (brew/AUR) | JDWP/jdb (in the JDK) |
| `setup-sbcl.sh` | SBCL + Quicklisp | none — CL uses Swank/Slynk via the editor | SBCL built-in |

These scripts share the package-manager logic in `lib/pkg.sh`, and the name mappings in
[`lib/packages.conf`](#the-package-table) — the `toolchain` rows. They write shell init to
`~/.bashrc.d/` with a marker, so cleanup can find it. They never write a tracked dotfile.

### Cleanup

`./cleanup.sh` undoes an install. It removes this repo's symlinks, the managed `~/.bashrc.d`
files, the fonts, and the generated config. It unsets the git config it set. `-a` also removes the
toolchains — sdkman, quicklisp and uv, but never `~/go`. It refuses to run on a machine that a
different dotfiles checkout owns. It never uninstalls a system package; it prints the list
instead.

---

## Scripts in bin/

`install.sh` links each of these into `$HOME/bin`. Every one prints its own help with `--help`:
the commands, the environment variables it reads, examples, and the exit codes.

`bin/` holds only the commands a person runs. The engines they share live in `lib/`, and nothing
links them into `$HOME/bin`: `lib/sync-dotfiles` writes the symlinks, and `lib/pkg.sh` reads
`lib/packages.conf`. Reach the sync through `dotfiles sync`.

| Script | Purpose | With no argument |
| :--- | :--- | :--- |
| `dotfiles` | Update, check, sync and edit the repository. See below. | It prints the help. The shell function changes directory. |
| `manage-secrets` | Encrypt, decrypt and verify `dotfiles/.secrets`. The pre-commit hook runs `verify`. | It prints the help |
| `venv` | Create and inspect Python virtual environments. It prefers uv. | It prints the environment path |
| `vm` | Manage one QEMU machine through virsh and virt-install. | It picks a machine, and prints its status |
| `gnome-settings` | Apply, dump or restore the managed GNOME keys. | It prints the help |

None of them is a TUI, and **none of them needs a terminal**. `vm` and `manage-secrets get` offer
an `fzf` picker when a name is missing and a terminal is there, because looking a name up and
retyping it is the whole friction. Without a terminal, or without `fzf`, they print the names and
exit non-zero instead. So each one still behaves predictably in a shell, in a script, in the
pre-commit hook, and under an agent — a picker is never the only way in, and `-n`, `$VM_NAME` and a
named key all still work.

### The dotfiles command

`dotfiles` holds only the jobs that need several steps in the right order. It wraps nothing that
already works on its own: `install.sh`, `cleanup.sh` and the `setup-*.sh` scripts keep their own
interfaces.

| Command | Effect |
| :--- | :--- |
| `dotfiles` | Enter the repository. This is the shell function in `.helpers`. |
| `dotfiles update` | Pull, link the files, then check this machine. It names the files that need a full `./install.sh`, such as a new package or a new script in `bin/`. |
| `dotfiles status` | The branch, the gap to the upstream, the uncommitted edits, and one line on the health of the machine. |
| `dotfiles doctor` | Every check for this machine, in full. The same report as `./install.sh --check`. |
| `dotfiles sync` | Link the files, and nothing else. It passes `-n`, `--check`, `--backup` and a target directory to the engine. |
| `dotfiles edit [name]` | Find one tracked dotfile and open it in `$VISUAL` or `$EDITOR`. `fzf` picks between several matches. |
| `dotfiles path` | Print the repository root. The shell function reads it. |

Two details are deliberate:

* **The `cd` lives in the shell, and nothing else does.** A script cannot change the directory of
  its caller, so `.helpers` defines a `dotfiles` function for that one case. Every other argument
  goes to `bin/dotfiles`, which an agent or a script can call directly. Earlier versions installed
  an alias instead; `install.sh` removes it, because an alias would hide the function.
* **`update` refuses to run when a different checkout owns `$HOME`.** It would otherwise relink the
  home directory to this repository. `install.sh` refuses for the same reason.

---

## Editor

* **Visual editor** — VS Code (`code --wait`). Git uses it for a commit or a merge. Use it for a
  large edit.
* **Terminal editor** — vi. Use it for a quick edit. The minimal `.vimrc` gives syntax
  highlighting and standard behaviour.

`.bash_profile` sets both. To change the editor on one machine, drop a file in `~/.bashrc.d/`,
which is sourced last, and export the three variables:

```bash
export EDITOR=emacs VISUAL=emacs GIT_EDITOR=emacs
```

---

## Secrets

This repository keeps sensitive environment variables in git: API keys and tokens. GPG and a
YubiKey encrypt them.

### Prerequisites

* A **YubiKey** that holds your PGP private keys.
* Your public key in `dotfiles/public.asc`. The install imports it.

### Packages for the YubiKey

**Debian and Ubuntu**
```bash
sudo apt update
sudo apt install -y gnupg gnupg-agent scdaemon pcscd
```

**Arch**
```bash
sudo pacman -S --needed gnupg pcsclite ccid pcsc-tools
sudo systemctl enable --now pcscd.socket
```

`install.sh` does both Arch steps for you. It installs `pcsclite` and `ccid`, with `yay` when
present and `pacman` otherwise, then enables `pcscd.socket`. The commands above are the manual
equivalent.

**macOS**
```bash
brew install gnupg
```

### Initialise GnuPG
```bash
gpg -k
```

### Workflow

The helpers load with `.bashrc`. To load them by hand:

```bash
source ~/.helpers
```

| Action | Command | Effect |
| :--- | :--- | :--- |
| **Add a secret** | `add_secret KEY` | Ask for the value without an echo, encrypt it into `.secrets`, and export `KEY` to the current shell. |
| **Add a secret in one line** | `add_secret KEY VALUE` | The same, but the value lands in `~/.bash_history`, and `ps` shows it while the command runs. Prefer the form above. |
| **Load the secrets** | `load_secrets` | Decrypt every secret into an environment variable. It asks for the YubiKey PIN once a day. |
| **Verify** | `bin/manage-secrets verify` | Prove that no cleartext secret is in the commit. `git commit` runs it. |

### Example
```bash
# Store a new key. The shell asks for the value, and does not echo it.
# The YubiKey asks for a touch or a PIN.
add_secret OPENAI_API_KEY

# Load the keys at the start of a session.
load_secrets
```

`.bashrc` sets `HISTCONTROL=ignoreboth`, so a command that starts with a space
stays out of the history file. `HISTIGNORE` also drops any `add_secret` line that
carries a value.

---

## Terminal agent and second brain

[OpenCode](https://opencode.ai) is the terminal agent. Its global config ships from
`dotfiles/.config/opencode/`: the behavioural rules in `AGENTS.md`, and the commands for the
Obsidian vault — `/brief`, `/daily`, `/kb`, `/project`, `/remind` and `/report`.

The vault lives at `$OBSIDIAN_VAULT`, and defaults to `~/vault`. Two helpers in `.helpers` work
from the shell: `jot <text>` appends to today's daily note without an LLM, and `sb` opens the
agent over the vault.

---

## Ghostty

The config is in `dotfiles/.config/ghostty/`. The Quake-style quick terminal is **opt-in per
machine**, through the untracked `config.local`. The installer enables it on macOS. Linux needs
compositor setup first — see `quick-terminal.conf`. GNOME cannot host it at all, so
`bin/gnome-settings` binds Super+Return to a normal Ghostty window there.

---

## lazygit

The config is in `dotfiles/.config/lazygit/config.yml`. `lg` is the alias.

lazygit runs its own `git diff` and **ignores `core.pager`**, so the config names `delta` a second
time. Three flags matter:

* `--paging=never` stops delta from starting a pager inside lazygit's panel.
* `--no-gitconfig` makes delta ignore the machine's `[delta]` keys. A machine that sets
  side-by-side globally is unreadable in a panel this narrow, and delta cannot turn the option off
  for one call.
* `--dark` matches the terminal theme.

The config sets no editor and no theme, on purpose. lazygit reads `EDITOR` and `VISUAL` from
`.bash_profile`, and it draws with the colours of the terminal, so the Ghostty theme already
applies.

`Ctrl-G` in the Local Branches tab runs `git-gone` from `.helpers`, which deletes every local
branch whose upstream is gone. It runs through `bash -lc`, because `git-gone` is a shell function.

lazygit reads `~/.config/lazygit/` on Linux, but `~/Library/Application Support/lazygit/` on
macOS. `.bash_profile` therefore exports `LG_CONFIG_FILE`, so one file serves both. Run
`lazygit --print-config-dir` when a machine seems to ignore the config. That command follows
`LG_CONFIG_FILE` only when the file at the end of it exists. An answer of
`Library/Application Support` on macOS therefore means the symlink is missing, not the export.

---

## tmux

The config is `dotfiles/.config/tmux/tmux.conf`, and the menus it reads are in
`dotfiles/.config/tmux/menu/`. It needs tmux 3.2 or newer, for `display-popup` and
`terminal-features`.

**C-x is the leader**, as it is in emacs. It is not the tmux `prefix` option, though. tmux resolves
the prefix key before it reads the root key table, so a real prefix swallows C-x and no binding can
act on it. `prefix` is therefore `None`, and C-x is bound in the root table to open a menu.

### The which-key layer

C-x opens a menu of the keys it accepts, the way `which-key` does in emacs. The keys work at
speed whether or not you read the menu, so `C-x 2` still splits a pane. Five rows open a submenu:

| Key | Menu | Holds |
| --- | ---- | ----- |
| `C-x C-p` | pane | focus with `h j k l`, move with `H J K L`, split, mark and join, break out |
| `C-x C-t` | window | new, rename, next, previous, reorder, find, kill |
| `C-x C-n` | resize | `h j k l` by a step, `H J K L` by one cell, tile evenly |
| `C-x C-o` | session | pick, next, previous, new, rename, detach, kill, reload the config |
| `C-x C-s` | copy | copy mode, search, top and end of the history, paste, buffer list |

Rows that repeat hold their menu open, so `C-x C-n l l l` widens a pane three steps. A key that no
row claims closes the menu and does nothing, which makes Escape and `C-g` the cancel keys and
means a typo cannot fire the wrong command.

Two limits are worth knowing, because both are tmux's and neither can be worked around:

* **No arrow key can be a menu row.** A tmux menu keeps the whole arrow family, with every
  modifier, for moving its own selection. Pane moves therefore sit on `H J K L`, and on
  `M-S-<arrow>` outside the menu.
* **A menu taller than the terminal does not draw**, and its keys go with it. Each menu stays
  under 21 rows, which fits a 24-row terminal. Keep it that way when you add a row.

### Keys that need no leader

`M-<arrow>` and `M-h/j/k/l` move the focus, `M-S-<arrow>` moves the pane itself, `M-n` splits,
`M-i` and `M-o` reorder the window, `M-[` and `M-]` cycle the layout, and `M-f` opens a shell in a
popup. `C-x ?` lists them from tmux itself, so the list cannot go stale.

### emacs in the terminal

Alt and C-x both shadow keys that readline and emacs want: `M-f`, `M-b`, `M-l`, `M-k`, and the
whole C-x map. Two ways out:

* `C-x C-x` sends one literal C-x to the program in the pane, so `C-x C-x C-s` saves a buffer.
* **F12 turns the whole layer off**, which is the better answer for a long emacs session. Every
  key then reaches the program, mouse events included. The left of the status bar turns yellow and
  says `KEYS OFF`, because otherwise tmux looks broken. F12 turns it back on.

### Sessions

`.aliases` holds the shell side: `tl` lists, `ta` goes to a session and picks one with `fzf` when
you name none, `tm` goes to the session named `main`, `tn <name>` goes to one by name, and `tkill`
kills the server. `ta`, `tm` and `tn` create the session when it is not there, and all three work
both inside and outside tmux: inside, they switch the client, because attaching a client to its own
server nests it.

---

## Linux desktop (GNOME + Arch)

### GNOME settings

`gsettings` is the GNOME counterpart of `defaults write` on macOS. `bin/gnome-settings` manages a
small **allowlist** of keys. A full `dconf dump /` is not tracked on purpose: it is
machine-specific, and unreadable in a diff.

| Command | Effect |
| :--- | :--- |
| `gnome-settings apply` | Set the managed keys. `install.sh` runs this when it detects GNOME. |
| `gnome-settings dump` | Print the current value of every managed key. |
| `gnome-settings restore` | Put the pre-dotfiles values back. `cleanup.sh` runs this. |

It manages these keys today:

* The Emacs key theme. GTK4 needs the gsettings key, because `settings.ini` covers GTK2 and GTK3
  only.
* The dark colour scheme, and 0xProto as the monospace font.
* Caps Lock as Control, and the key-repeat rates.
* Night Light, and fractional scaling.
* Ghostty as the desktop terminal, and the window keys below.

The first apply writes the previous values to `~/.local/state/dotfiles/gnome-settings.json`.

### Window and workspace keys

Super stays a window-manager key on Linux, as i3 and Hyprland use it. The terminal shortcuts do
**not** match macOS: `Ctrl+C` cannot be the copy key in a terminal. Linux keeps `ctrl+shift+…`,
and macOS keeps `cmd+…`.

| Key | Action |
| :--- | :--- |
| `Super+Return` | Ghostty — the i3/sway/Hyprland idiom for "terminal". |
| `Super+1…4` | Jump to that workspace. |
| `Super+Shift+1…4` | Move the focused window to that workspace. |
| `Super+Alt+Left/Right` | Previous or next workspace (a GNOME default, kept as is). |

This displaces two GNOME defaults. `Super+N` normally switches to the Nth **application** in the
dash, so `gnome-settings` clears those bindings. The workspaces become **static**, and there are
four of them (`WORKSPACES` in `bin/gnome-settings`), because a dynamic count has nothing to jump
to when the desktop is quiet. `gnome-settings restore` puts both back.

### Drop-down terminal

Ghostty's own quick terminal needs `wlr-layer-shell`, which Mutter does not implement. On Wayland,
nothing outside the shell can raise or hide the window of another app. A GNOME Shell extension is
therefore the only route. `install.sh` installs
[Quake Terminal](https://extensions.gnome.org/extension/6307/quake-terminal/)
(`quake-terminal@diegodario88.github.io`). It drops down the **Ghostty** window that is already
there, so one terminal config still covers macOS and Linux.

`install.sh` asks the extensions.gnome.org API for the build that matches the shell version of
this machine. It installs the build with `gnome-extensions`, which ships inside gnome-shell. No
extra tool is necessary. `cleanup.sh` removes the extension.

After the first install, **log out and back in**: the shell loads a new extension at start only.
Then set the hotkey in the preferences of the extension. `F12` is the Guake convention, and it
collides with nothing. For ``Super+` ``, clear the GNOME `switch-group` binding first, because
Mutter grabs that key before any app sees it.

`gnome-settings` does not track the settings of the extension yet, because its schema keys have to
be read on a machine that has the extension. To track them, set the hotkey, run
`gsettings list-recursively org.gnome.shell.extensions.quake-terminal`, and add the keys to
`SETTINGS` in `bin/gnome-settings`.

### SSH agent: gpg-agent, not the GNOME agent

`.bashrc` points `SSH_AUTH_SOCK` at gpg-agent, but that covers **login shells only**. Graphical
apps — VS Code and the GNOME apps — read the systemd user environment. There, the GNOME agent
would claim the variable, and never ask the YubiKey. Three parts fix it:

* `dotfiles/.config/environment.d/10-gpg-ssh.conf` sets `SSH_AUTH_SOCK` for the whole session.
* `install.sh` enables `gpg-agent-ssh.socket`, so the agent listens before an app asks.
* `install.sh` masks `gcr-ssh-agent` or `gnome-keyring-ssh`, whichever this GNOME version ships.

**Log out and back in** after the first install. The session reads its environment at login.

HTTPS git remotes use `git-credential-libsecret`, the GNOME keyring, when the helper is present.
They do not use a cleartext `~/.git-credentials`.

### systemd user units

These are the Linux counterpart of a macOS LaunchAgent. Drop a `*.service`, `*.timer` or
`*.socket` file in `dotfiles/.config/systemd/user/`. `install.sh` reloads systemd, and enables
every unit that has an `[Install]` section. `cleanup.sh` disables them again.

### Arch upkeep

`install.sh` installs `pacman-contrib`, and enables `paccache.timer` for a weekly cache trim. The
aliases wrap the rest:

| Alias | Command | Why |
| :--- | :--- | :--- |
| `pacup` | `checkupdates` | List updates without touching the sync database. |
| `pacnew` | `pacdiff` | Merge the `.pacnew` files an upgrade leaves behind silently. |
| `paccleanup` | `paccache -rk2` | Trim the package cache by hand. |
| `pacorphans` | `pacman -Qtdq` | List orphaned dependencies. |

`dotfiles/.makepkg.conf` builds AUR packages with every core, and skips package compression.
Nothing packages an AUR helper, so `install.sh` builds `yay-bin` once on a fresh Arch machine.
Without it, the AUR-only packages (`jdtls`) are skipped.

---
