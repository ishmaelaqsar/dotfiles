# Dotfiles

**Author:** Ishmael Aqsar

Configuration files, maintenance scripts, and GPG-encrypted secrets for my development
environment. They work on **macOS**, **Linux**, and inside **VS Code Dev Containers**. Build notes
for the home servers are in `docs/`, as Org files.

---

## Bootstrap

### Option A: VS Code Dev Containers

VS Code can install the dotfiles in every container. Open Settings (`Cmd+,` or `Ctrl+,`), search
for **Dotfiles**, and set three fields:

1. **Repository** — `ishmaelaqsar/dotfiles`
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
   `eza`, `fd`, `ripgrep`, `fzf`, `git-delta`, `tmux` and more. The list is data —
   see [The package table](#the-package-table). Some packages are best-effort: `lazydocker` is
   not in Debian's repos. It also installs
   [OpenCode](https://opencode.ai) and [Ghostty](https://ghostty.org), which can fail without
   stopping the run. On Arch it builds **yay** first when no AUR helper exists.
2. **Link the config files** (`.bashrc`, `.editorconfig`, and the rest) into your home directory.
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
* `install.sh` does not install Emacs. `setup-emacs.sh` does, on a machine that wants it.

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
  exists. `toolchain` and `virt` are never active; those rows only map a name — `toolchain`
  for a `setup-*.sh` script, and `virt` for the libvirt stack that `bin/vm` drives.
* **overrides** — `mgr=pkg` pairs. An exact manager wins first, then `*=pkg`, then the first
  command name.

`lib/pkg.sh` reads the table. To add a tool, add a row. No script changes.

### Language toolchains

`install.sh` stops at the shell and terminal tools. Each language environment is a separate
script: the compiler or runtime, the LSP server, and the debugger. Run them by hand, only on a
machine that needs them. They are idempotent.

| Script | Toolchain | LSP | Debugger |
| :--- | :--- | :--- | :--- |
| `setup-c.sh` | C/C++ (CLT / build-essential / base-devel), cmake | clangd | lldb, gdb + valgrind (Linux); Dape in Emacs |
| `setup-python.sh` | uv (manages interpreters) | ruff + basedpyright | debugpy |
| `setup-go.sh` | go | gopls | delve |
| `setup-java.sh` | sdkman → Temurin LTS, maven, gradle | jdtls (brew/AUR) | JDWP/jdb (in the JDK) |
| `setup-sbcl.sh` | SBCL + Quicklisp | none — CL uses Swank/Slynk via the editor | SBCL built-in |
| `setup-emacs.sh` | Emacs 30 (`emacs-plus@30` on macOS, the pgtk package on Linux) and the packages `init.el` selects: Sly, Magit, Vertico, Orderless, Consult, Marginalia, Embark, Avy, Corfu, Cape, Dape | `eglot`, built in, over the servers the rows above install | none |
| `setup-yk.sh` | [yk](https://github.com/ishmaelaqsar/yk), the YubiKey maintenance tool | none | none |

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
| `manage-secrets` | Encrypt, decrypt, list and verify `dotfiles/.secrets`. The pre-commit hook runs `verify`. | It prints the help |
| `venv` | Create and inspect Python virtual environments. It prefers uv. | It prints the environment path |
| `vm` | Manage one QEMU machine through virsh and virt-install. A missing tool is reported with the package name this host uses. | It picks a machine, and prints its status |
| `gnome-settings` | Apply, dump or restore the managed GNOME keys. | It prints the help |
| `ediff` | Compare two files in Emacs, in the terminal. `pacnew` runs it as `DIFFPROG`. | It prints an Emacs error |
| `md2org` | Convert markdown files to Org with `pandoc`, one `.org` beside each. | It prints the usage |

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

Emacs, where `setup-emacs.sh` has installed it. `.bash_profile` then sets `EDITOR` to
`emacsclient -t -a ''` and `VISUAL` to `emacsclient -c -a ''`: the terminal for a git commit, a
frame for a large edit, and `-a ''` starts the daemon when none runs. A machine with `emacs` but
no client gets `emacs -nw -q`; a machine with no Emacs keeps vi. Two openers: `ce` picks a
directory under `$WORKSPACE` with fzf and opens it in a frame, and `alt+shift+o` in Ghostty does
the same for the current directory.

The init is `dotfiles/.config/emacs/init.el`, written in the built-in `use-package` on Emacs 30:
`eglot` over the language servers the other `setup-*.sh` scripts install, the tree-sitter modes
with a grammar fetched on first use, terminal polish for `emacsclient -t` (mouse, OSC 52
clipboard, 24-bit colour), and generated files under `~/.local/state/emacs/` (`early-init.el`
sends the native-compilation cache there too). Five packages come from MELPA: Sly for Common
Lisp, Magit on `C-x g`, and Vertico, Orderless and Consult, which make the minibuffer the fuzzy
picker. `consult-ripgrep` and `consult-fd` run the installed `rg` and `fd` with a live preview,
and `xref` searches with `rg` as well. fzf stays in the shell. No framework, and no vim keys: the
point is the Emacs keys the rest of the repository already uses.

Five more packages, all from GNU ELPA: Marginalia annotates every candidate; Embark acts on the
candidate or the thing at point (`C-.`, `C-;`), and any prefix followed by `C-h` lists its keys;
Avy jumps to a visible position (`M-j`, then the characters you see); Corfu completes at point
in a graphical frame, with Cape adding buffer words and file paths. A terminal frame on Emacs 30
cannot draw Corfu's child frame, so it keeps the built-in completion there.

For C and C++, `clangd` from `setup-c.sh` is the language server, and `~/.clang-format` is the
style for code with no `.clang-format` of its own: `clang-format` stops at the first one it meets
walking up from the file, so a project's file wins. Debugging has two routes: `M-x gdb` and
`M-x lldb` from `gud`, text only, and Dape (`C-x C-a d`), a DAP client with breakpoints in the
margin and locals in a side window, over gdb's own DAP mode on Linux and `lldb-dap` on macOS.

Startup is measured, not guessed: `early-init.el` holds the garbage collector and the file-name
handlers during init and turns on `package-quickstart`; the daemon starts in about 0.45 s. After
`M-x package-install`, run `M-x package-quickstart-refresh`. `M-x use-package-report` shows the
load time of each package when one feels slow.

To change the editor on one machine, drop a file in `~/.bashrc.d/`, which is sourced last, and
export the three variables:

```bash
export EDITOR=emacs VISUAL=emacs GIT_EDITOR=emacs
```

---

## Org

Notes live in `$ORG_DIR`, default `~/org/`, which `.bash_profile` exports. The Obsidian vault
stays markdown: Obsidian and the six vault commands read `.md`. `C-c c` captures into
`inbox.org`, `C-c a` opens the agenda over the directory, and `<s TAB` inserts a source block.

A literate notebook is an Org file with one header line:

```org
#+PROPERTY: header-args :session nb :results output
```

Every block then shares one interpreter, so a variable from the first block is visible in the
second. `C-c C-c` runs the block under point and asks once, because `org-confirm-babel-evaluate`
stays on. Babel is loaded for Emacs Lisp, shell, Python, C, Common Lisp (through Sly) and SQLite.
A session is a process that Org never stops, so closing the last Org buffer kills the
interpreters, and `M-x my/org-babel-kill-sessions` does it by hand.

`md2org FILE.md` writes `FILE.org` beside it through `pandoc`, for the markdown you move over.

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
| **List the names** | `manage-secrets list` | Print every key name. It decrypts nothing, so it never asks the YubiKey. |
| **Read one secret** | `manage-secrets get [KEY]` | Print one value. With no key it picks one, then decrypts only that. |
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

### Key maintenance

[yk](https://github.com/ishmaelaqsar/yk) renews, rotates and reports on the subkeys. `setup-yk.sh`
clones it into `~/.local/share/yk` and links `~/bin/yk`. `.bash_profile` exports `YK_PUBKEY`, the
public key that `sync-dotfiles` links to `~/public.asc`, so `yk status` and `yk remind` need no
argument. The first shell of each day runs `yk remind`. It prints nothing while every subkey is
more than 90 days from its expiry, and a short report when one is not. The stamp that limits it
to one run a day is `~/.local/state/dotfiles/yk-remind`.

---

## Terminal agent and second brain

[OpenCode](https://opencode.ai) is the terminal agent. Its global config ships from
`dotfiles/.config/opencode/`: the behavioural rules in `AGENTS.md`, and the commands for the
Obsidian vault — `/brief`, `/daily`, `/kb`, `/project`, `/remind` and `/report`.

`AGENTS.md` makes the agent a tutor. It asks what you tried, names the mechanism, and points
at the primary source. It does not write the solution, and there is no escape word. A
command is not a question: run, edit, and the vault commands are done as asked.

The vault lives at `$OBSIDIAN_VAULT`, and defaults to `~/vault`. Two helpers in `.helpers` work
from the shell: `jot <text>` appends to today's daily note without an LLM, and `sb` opens the
agent over the vault.

---

## Ghostty

`install.sh` installs Ghostty where a package exists: brew on macOS, the Arch repos, and the
Ubuntu repos from 26.04. Debian needs a `.deb`, and Fedora needs a COPR. Each warning names
the source.

The config is in `dotfiles/.config/ghostty/`. The Quake-style quick terminal is **opt-in per
machine**, through the untracked `config.local`. The installer enables it on macOS. Linux needs
compositor setup first — see `quick-terminal.conf`. GNOME cannot host it at all, so
`bin/gnome-settings` binds Super+Return to a normal Ghostty window there.

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
| `C-x t` | tools | Magit, lazydocker, the `vm` picker, htop, ncdu — each in a popup |

The tools rows open a popup, so a full-screen program borrows the whole terminal and gives it back
on exit. Each row checks for its tool first and says so when it is missing, rather than flashing an
empty frame. A popup inherits the environment of the tmux **server**, so a tool installed after the
server started is not on its `PATH` until the server restarts.

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

### Emacs in the terminal

C-x and eight Alt keys are Emacs keys, so in a pane that runs `emacs` or `emacsclient` the layer
is off by itself. Every root binding tests `pane_current_command` and sends the key through when
it matches; `C-x C-f` opens a file and `M-f` moves a word, with no toggle. Elsewhere the layer is
unchanged. Two escapes remain for other programs:

* `C-x C-x` sends one literal C-x to the program in the pane, which is what readline wants.
* **F12 turns the whole layer off** for any other full-screen program. Every key then reaches
  it, mouse events included. The left of the status bar turns yellow and says `KEYS OFF`, because
  otherwise tmux looks broken. F12 turns it back on.

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
