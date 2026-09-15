# Dotfiles

Configuration files, maintenance scripts, and GPG-encrypted secrets for a development
environment on **macOS**, **Linux**, and **VS Code Dev Containers**. Build notes for the home
servers are in `docs/`, as Org files.

---

## Install

### VS Code Dev Containers

VS Code can install the dotfiles in every container. Open Settings, search for **Dotfiles**, and
set three fields:

1. **Repository**: `ishmaelaqsar/dotfiles`
2. **Install Command**: `install.sh`
3. **Target Path**: `~/.dotfiles`

### macOS and Linux

```bash
git clone https://github.com/ishmaelaqsar/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` installs the packages in `lib/packages.conf` with the manager it finds. It links the
files under `dotfiles/` into your home directory, and the scripts in `bin/` into `~/bin`. It
installs the 0xProto Nerd Font, writes the global git config, configures the GPG agent for SSH
and the YubiKey, and installs the git hooks. On Linux it also enables the systemd user units and
applies the GNOME settings. On Arch it builds `yay` first when no AUR helper exists. It does not
install Emacs; `setup-emacs.sh` does.

`./install.sh --help` lists the flags. Three matter before a real run:

- `-n` prints the whole plan and changes nothing.
- `--check` reports what is missing or has drifted. See the next section.
- `./install.sh /some/dir` is a **probe run**: it writes the file layout into that directory and
  skips the packages, the git config, and the GPG keyring. Use it to test a change.

In a terminal, the script asks before each optional group: the packages, the desktop steps, the
Hyprland helpers, OpenCode, and Ghostty. Enter keeps the default, which is yes. `-y` skips the
questions, and so does a run with no terminal, such as the dev-container hook or an agent shell.
The script refuses to run when a different dotfiles checkout owns `~/.dotfiles`; `-f` overrides
that. It repeats every warning as a numbered summary at the end.

Two notes for a fresh machine. On macOS, `/usr/bin/python3` is a stub until you run
`xcode-select --install`, and `lib/sync-dotfiles` needs a working `python3`. After the install,
run `opencode auth login` once.

### Check an existing install

```bash
./install.sh --check           # this machine
./install.sh --check /some/dir # a probe target
dotfiles doctor                # the same report, by its shorter name
```

The check reads the machine, changes nothing, and exits non-zero when a repair is necessary. A
missing symlink, script link, font, `gpg-agent.conf`, or git setting is a failure. A package
command that is not on `PATH` is a warning, because packages are best-effort. Run `./install.sh`
to repair what it reports.

### Packages

`lib/packages.conf` holds every package as one row: the commands it provides, the tags that
select it, and per-manager package names. Its header documents the format. `lib/pkg.sh` reads the
table, so a new tool is a new row and no script change. The tags are `base`, `linux`, `desktop`,
`arch`, `hyprland`, `toolchain`, and `virt`.

### Language toolchains

Each language environment is a separate script: the compiler or runtime, the language server, and
the debugger. Run them by hand, on a machine that needs them. They are idempotent, each takes
`-h`, and none takes a dry run.

| Script | Toolchain | Language server | Debugger |
| :--- | :--- | :--- | :--- |
| `setup-c.sh` | C and C++ (CLT, build-essential, or base-devel), cmake | clangd | lldb; gdb and valgrind on Linux |
| `setup-python.sh` | uv, which manages the interpreters | ruff and basedpyright | debugpy |
| `setup-go.sh` | go | gopls | delve |
| `setup-java.sh` | sdkman, Temurin LTS, maven, gradle | jdtls | jdb, in the JDK |
| `setup-sbcl.sh` | SBCL and Quicklisp | none; Sly talks to Slynk | SBCL built-in |
| `setup-emacs.sh` | Emacs and the packages `init.el` selects | `eglot`, built in | none |
| `setup-yk.sh` | [yk](https://github.com/ishmaelaqsar/yk), the YubiKey maintenance tool | none | none |

The scripts share `lib/pkg.sh` and the `toolchain` rows of the package table. They write shell
init to `~/.bashrc.d/` with a marker, so cleanup can find it, and never write a tracked dotfile.

### Cleanup

`./cleanup.sh` undoes an install: the symlinks, the managed `~/.bashrc.d` files, the fonts, the
generated config, and the git settings. `-a` also removes the toolchains, but never `~/go`. It
refuses to run on a machine that a different checkout owns, and it never uninstalls a system
package; it prints the list instead.

---

## Scripts in bin/

`install.sh` links each of these into `~/bin`. Every one prints its help with `--help`. `bin/`
holds only the commands you run; the engines they share live in `lib/`, and `dotfiles sync`
reaches the symlink engine.

| Script | Purpose | With no argument |
| :--- | :--- | :--- |
| `dotfiles` | Update, check, sync, and edit the repository. | Prints the help. The shell function enters the repository. |
| `manage-secrets` | Encrypt, decrypt, list, and verify `dotfiles/.secrets`. | Prints the help. |
| `venv` | Create and inspect Python virtual environments, with uv. | Prints the environment path. |
| `vm` | Manage one QEMU machine through virsh and virt-install. | Picks a machine and prints its status. |
| `gnome-settings` | Apply, dump, or restore the managed GNOME keys. | Prints the help. |
| `ediff` | Compare two files in Emacs, in the terminal. `pacnew` runs it as `DIFFPROG`. | Prints an Emacs error. |
| `md2org` | Convert markdown files to Org with `pandoc`, one `.org` beside each. | Prints the usage. |
| `docker` | Run `podman` under the name that lazydocker and compose files call. | Prints the podman help. |
| `git-gone` | Delete every local branch whose upstream is gone. `git gone` runs it too. | Deletes the merged ones; `--force` takes the rest. |
| `tmux-sessions` | Pick, create, or kill tmux sessions from an `fzf` list. `M-s` opens it. | Lists the sessions; Enter switches, C-x kills. |

None of them needs a terminal. `vm` and `manage-secrets get` open an `fzf` picker only when a
name is missing and a terminal is there. Otherwise they print the names and exit non-zero, so a
script, the pre-commit hook, and an agent get the same behaviour.

### The dotfiles command

`dotfiles` with no argument is a shell function in `.helpers` that enters the repository, because
a script cannot change the directory of its caller. Every other argument goes to `bin/dotfiles`.

| Command | Effect |
| :--- | :--- |
| `dotfiles update` | Pull, link the files, then check this machine. It names the files that need a full `./install.sh`. |
| `dotfiles status` | The branch, the gap to the upstream, the uncommitted edits, and one line on the machine. |
| `dotfiles doctor` | Every check for this machine. The same report as `./install.sh --check`. |
| `dotfiles sync` | Link the files, and nothing else. It passes `-n`, `--check`, and a target directory through. |
| `dotfiles edit [name]` | Find one tracked dotfile and open it in `$VISUAL` or `$EDITOR`. |
| `dotfiles path` | Print the repository root. |

`update` refuses to run when a different checkout owns `$HOME`, as `install.sh` does.

---

## Testing

CI runs on every push to `main` and on every pull request, from `.github/workflows/ci.yml`:

- **parity**: `test/pkg-parity.sh` proves that `lib/pkg.sh` and `lib/pkgconf.py` read every row of
  `lib/packages.conf` the same way.
- **shellcheck**: every tracked file with a `sh` or `bash` shebang, at warning level and up.
- **python**: every Python entry point byte-compiles.
- **elisp**: in a Debian container, the selected packages install, `lisp/*.el` byte-compiles with
  warnings as errors, and `init.el` loads in batch.
- **smoke**: `test/linux-smoke.sh quick` in a Debian container. A dry run changes nothing,
  `install.sh` runs with no terminal, the doctor passes, and `cleanup.sh -a` removes it all.

The same checks run locally:

```bash
bash test/pkg-parity.sh
docker run --rm -v "$PWD":/repo:ro debian:stable bash /repo/test/linux-smoke.sh quick
emacs --batch -l dotfiles/.config/emacs/early-init.el --eval '(package-initialize)' \
  -l dotfiles/.config/emacs/init.el --eval '(kill-emacs)'
```

---

## Emacs

`.bash_profile` sets `EDITOR` to `emacsclient -t --alternate-editor=` and `VISUAL` to
`emacsclient -c --alternate-editor=`: the terminal for a quick edit, a frame for a large one, and
a daemon started when none runs. `GIT_EDITOR` is `emacs -nw -q`, a plain Emacs with no init, so a
commit does not depend on the daemon. A machine with no Emacs keeps vi. To change the editor on
one machine, export the three variables from a file in `~/.bashrc.d/`, which is sourced last.

`setup-emacs.sh` keeps a daemon warm: the systemd user unit in
`dotfiles/.config/systemd/user/emacs.service` on Linux, `brew services` on macOS. Restart it
after an init change with `emacsclient -e '(kill-emacs)'`. Plain `emacs` on macOS opens the GUI
app and holds the terminal; use `emacsclient -t` for a terminal frame. Three openers: `e file` opens a file in the terminal. `ce` picks a directory
under `$WORKSPACE` and opens it in a frame. `alt+shift+o` in Ghostty opens the current directory
in a frame.

The init is `dotfiles/.config/emacs/init.el`, on the built-in `use-package` for Emacs 30 and
31. Its comments explain each choice. In outline: `eglot` over the language servers the
`setup-*.sh` scripts install, and tree-sitter modes with a grammar fetched on first use. Vertico,
Orderless, and Consult make the minibuffer the fuzzy picker over `rg` and `fd`, with Marginalia,
Embark, and Avy. Corfu with Cape completes at point. Magit is on `C-x g`, Sly and paredit serve
Lisp, and Dape debugs. Generated files go under `~/.local/state/emacs/`. No framework, no vim
keys.

| Language | Server | Format on save | Debug |
| :--- | :--- | :--- | :--- |
| C and C++ | clangd | clangd, with `~/.clang-format` where a project has none | Dape over gdb or `lldb-dap`; `M-x gdb` for text |
| Python | basedpyright | ruff, imports then format | Dape over `debugpy-adapter` |
| Go | gopls | gopls, imports organised first | Dape |
| Java | jdtls | jdtls, 4 spaces | none |

`C-c f` formats on demand. `~/.config/emacs/lisp/site.el`, a machine-local file, turns the
save-time formatting off under a shared repository, so its diffs stay small. Diagnostics show at
the end of the line; `M-n` and `M-p` walk them, and `M-g f` lists them.

### Shells

`C-c t` opens a bash in an [eat](https://codeberg.org/akib/emacs-eat) buffer, and `C-x p s`
opens one in the project root. `C-x p e` opens eshell, whose full-screen commands run in eat. The
`.aliases` functions and the fzf keys work there, because it is the same bash. In a terminal
frame, tmux stays the terminal.

### kdb

`dotfiles/.config/emacs/lisp/kdb.el` runs q buffers against a remote kdb server from a local `q`.
It needs `q` on `PATH` and a list of servers in `kdb-targets`. Put that list in
`~/.config/emacs/lisp/kdb-site.el`, a machine-local file that `init.el` loads when it exists.
`C-c k n` opens a scratch buffer on a target, where each result shows under its statement, and
`C-c k i` toggles that in any buffer.

### Org

Notes live in `$ORG_DIR`, default `~/org/`. The Obsidian vault stays markdown, because Obsidian
and the vault commands read `.md`. `C-c c` captures into `inbox.org`, `C-c a` opens the agenda,
and `<s TAB` inserts a source block. A file with the header
`#+PROPERTY: header-args :session nb :results output` is a notebook: every block shares one
interpreter. `C-c C-c` runs the block under point and asks once. Closing the last Org buffer kills
the interpreters. `md2org FILE.md` writes `FILE.org` beside it.

### Reading

EWW is the browser for a page of text, and Emacs opens every link in it. `C-c w` opens a URL, and
offers the one at point. In the page, `R` renders an article readable, `&` sends it to the system
browser, and `C-x r m` bookmarks it. Video, the Google apps, GitHub, and a local server keep the
system browser, because each needs JavaScript or a session.

`C-c e` opens [elfeed](https://github.com/emacs-elfeed/elfeed), the feed reader. `G` fetches, `s`
filters, and `RET` opens an entry. The feed list is `dotfiles/.config/emacs/elfeed.org`, where a
headline that starts with `http` is a feed and takes the tags of its ancestors. The repository
tracks that file, so every machine reads the same feeds. The database is generated state under
`~/.local/state/emacs/elfeed/`, so what you have read stays on the machine that read it.

### Mail

`C-c m` starts Gnus. It reads the mailbox over IMAP, reads public list archives over NNTP, and
sends through smtpmail. Every part of it ships with Emacs.

Before the first run, put two lines in `~/.config/emacs/authinfo.gpg`. Open that path in Emacs
and save it, and Emacs encrypts the file to your key:

```
machine imap.gmail.com login YOU@gmail.com port 993 password APP-PASSWORD
machine smtp.gmail.com login YOU@gmail.com port 587 password APP-PASSWORD
```

The password is a Google app password, which needs two-step verification on the account. A
normal password is refused. Make a new one rather than reuse the app password the mail relay in
`docs/forgejo-setup.org` holds, so that revoking either leaves the other alone. Gmail rewrites a From address it does not know, so either add the
address as a "send mail as" alias, or set `user-mail-address` to the account address.

Two archive servers are configured and need no account: `lore` carries the kernel lists and
their neighbours, and `gmane` carries the GNU and Emacs ones. `A A` in the group buffer lists
what a server holds, and `u` subscribes to a group. A second mailbox is a second entry in
`gnus-secondary-select-methods` with its own name and host, plus two more lines in the same
credentials file.

Gnus keeps its group state, caches, and drafts under `~/.local/state/emacs/mail/`, so it leaves
no `News` or `Mail` directory behind. For patches, `git send-email` reads its own settings, which
stay out of this repository because they carry the login:

```bash
git config --global sendemail.smtpServer smtp.gmail.com
git config --global sendemail.smtpServerPort 587
git config --global sendemail.smtpEncryption tls
git config --global sendemail.smtpUser YOU@gmail.com
```

---

## Secrets

`dotfiles/.secrets` keeps API keys and tokens in git, encrypted with GPG to a key on a YubiKey.
The install imports the public key from `dotfiles/public.asc`. Run `gpg -k` once, so GnuPG
creates its directory.

The helpers load with `.bashrc`:

| Action | Command | Effect |
| :--- | :--- | :--- |
| Add a secret | `add_secret KEY` | Asks for the value without an echo, encrypts it, and exports `KEY` to the current shell. |
| Add a secret in one line | `add_secret KEY VALUE` | The same, but the value lands in the history and `ps` shows it. Prefer the form with no value. |
| Load the secrets | `load_secrets` | Decrypts every secret into an environment variable. The YubiKey asks for its PIN once a day. |
| List the names | `manage-secrets list` | Prints every key name. It decrypts nothing. |
| Read one secret | `manage-secrets get [KEY]` | Prints one value. With no key it picks one, then decrypts only that. |
| Verify | `manage-secrets verify` | Proves that no cleartext secret is in the commit. |

Two hooks enforce the last row. The pre-commit hook runs `verify`, and the pre-push hook scans
every outgoing commit, which catches `--no-verify`, an amend, or a rebase. `HISTIGNORE` drops any
`add_secret` line that carries a value.

[yk](https://github.com/ishmaelaqsar/yk) renews, rotates, and reports on the subkeys.
`setup-yk.sh` installs it, and `.bash_profile` exports `YK_PUBKEY`, so `yk status` and
`yk remind` need no argument. The first shell of each day runs `yk remind`, which prints nothing
while every subkey is more than 90 days from its expiry.

---

## Terminal agent and second brain

[OpenCode](https://opencode.ai) is the terminal agent. Its global config ships from
`dotfiles/.config/opencode/`: the rules in `AGENTS.md`, which make the agent a tutor that does
not write the solution, and the commands for the Obsidian vault: `/brief`, `/daily`, `/kb`,
`/project`, `/remind`, and `/report`. The vault lives at `$OBSIDIAN_VAULT`, default `~/vault`.
From the shell, `jot <text>` appends to today's daily note, and `sb` opens the agent over the
vault.

---

## Ghostty

`install.sh` installs Ghostty where a package exists: brew on macOS, the Arch repos, and the
Ubuntu repos from 26.04. Elsewhere it prints where to get one. The config is in
`dotfiles/.config/ghostty/`. The quick terminal is opt-in per machine through the untracked
`config.local`; the installer enables it on macOS, and `quick-terminal.conf` says what Linux
needs.

---

## tmux

The config is `dotfiles/.config/tmux/tmux.conf`, and the menus it reads are in
`dotfiles/.config/tmux/menu/`. It needs tmux 3.2 or newer. **C-x is the leader**, as in Emacs:
it opens a menu of the keys it accepts, the way `which-key` does, and the keys work without
reading the menu. Five rows open a submenu:

| Key | Menu | Holds |
| --- | ---- | ----- |
| `C-x C-p` | pane | focus with `h j k l`, move with `H J K L`, split, mark and join, break out |
| `C-x C-t` | window | new, rename, next, previous, reorder, find, kill |
| `C-x C-n` | resize | `h j k l` by a step, `H J K L` by one cell, tile evenly |
| `C-x C-o` | session | pick, next, previous, new, rename, detach, kill, reload the config |
| `C-x C-s` | copy | copy mode, search, top and end of the history, paste, buffer list |
| `C-x t` | tools | Magit, lazydocker, the `vm` picker, htop, ncdu, each in a popup |

A tools row checks its precondition first and says what is wrong, and every popup starts in the
directory of the current pane. tmux draws the tool's common keys in the popup border, so the hint
stays while the program owns the inside. Rows that repeat hold their menu open, so `C-x C-n l l l`
widens a pane three steps. A key that no row claims closes the menu and does nothing.

Some keys need no leader. `M-<arrow>` and `M-h/j/k/l` move the focus, and `M-S-<arrow>` moves
the pane. `M-n` splits, `M-i` and `M-o` reorder the window, and `M-[` and `M-]` cycle the layout.
`M-f` opens a shell in a popup. `C-x ?` lists them from tmux itself.

In a pane that runs Emacs, the layer is off by itself: every root binding tests
`pane_current_command` and sends the key through. `C-x C-x` sends one literal C-x to any other
program. F12 turns the whole layer off and on, and the status bar says `KEYS OFF` while it is.

`.aliases` holds the sessions. `tl` lists them, and `tkill` kills the server. `ta` goes to a
session, and picks one with `fzf` when you name none. `tm` goes to `main`, and `tn <name>` goes to
one by name. All three create the session when it is not there, inside or outside tmux.

---

## Containers

podman is the container engine, rootless, on Linux and macOS. On Linux `install.sh` enables
`podman.socket`. On macOS podman runs in a VM: `install.sh` creates it, and you start it with
`podman machine start` when you need it, because the VM costs memory while it runs.

`bin/docker` is a shim that runs `podman`, so lazydocker, the `lzd` alias, and the `C-x t d` tmux
row work with no lazydocker config. `.bash_profile` exports `DOCKER_HOST` when a podman socket
exists, and `.bashrc` gives `docker` the podman completion.

---

## Linux desktop

### GNOME settings

`bin/gnome-settings` manages a small allowlist of `gsettings` keys. A full `dconf dump /` is not
tracked, because it is machine-specific and unreadable in a diff.

| Command | Effect |
| :--- | :--- |
| `gnome-settings apply` | Set the managed keys. `install.sh` runs this on a graphical Linux machine. |
| `gnome-settings dump` | Print the current value of every managed key. |
| `gnome-settings restore` | Put the previous values back. `cleanup.sh` runs this. |

The managed keys: the Emacs key theme, the dark colour scheme, and 0xProto as the monospace
font. Caps Lock as Control, and the key-repeat rates. Night Light, and fractional scaling. Ghostty
as the desktop terminal, and the Super layout. GTK apps under Hyprland read the key theme and the
colour scheme from the same place. The script skips the schemas that only GNOME Shell installs.

### The Super layout

Super is the window-manager key. `bin/gnome-settings` and `dotfiles/.config/hypr/hyprland.conf`
bind the **same keys**, so the hands learn one layout. The terminal shortcuts do not match macOS:
Linux keeps `ctrl+shift+…`, because `Ctrl+C` cannot be the copy key in a terminal.

| Key | Action |
| :--- | :--- |
| `Super+Return` | Ghostty. |
| `Super+e` | An Emacs frame on the running daemon. |
| `Super+b` | The default web browser. |
| `Super+n` | The home folder in the default file manager. |
| `Super+Space` | The app launcher: the GNOME app grid, or `fuzzel` on Hyprland. |
| `` Super+` `` | The drop-down terminal. |
| `Super+Shift+s` | Screenshot of a region to the clipboard. |
| `Super+Escape` | Lock the screen. |

| Key | GNOME | Hyprland |
| :--- | :--- | :--- |
| `Super+q` | Close the window. | Close the window. |
| `Super+f` | Full screen. | Full screen. |
| `Super+m` | Toggle maximised. | Maximise without hiding the bar. |
| `Super+h` / `Super+l` | Tile left or right. | Focus left or right. |
| `Super+k` / `Super+j` | Maximise or unmaximise. | Focus up or down. |
| `Super+Shift+h j k l` | | Move the window that way. |
| `Super+Ctrl+h j k l` | | Resize the window. |
| `Super+v`, `Super+p`, `Super+s` | | Float, pseudo-tile, toggle the split direction. |
| `Super+Tab` | Switch application. | Cycle the windows. |
| `Super+1…4` | Jump to that workspace. | The same, and 5 and 6. |
| `Super+Shift+1…4` | Move the window to that workspace. | The same. |
| `Super+Alt+Left/Right` | Previous or next workspace. | The same. |
| `Super+Shift+e` | | **End the session.** It asks nothing, one Shift from `Super+e`. |

GNOME has no directional focus, so `h j k l` tile and maximise there. The layout displaces some
GNOME defaults, and `gnome-settings restore` puts every one back. The workspaces become static,
because a dynamic count has nothing to jump to.

### Hyprland

When `Hyprland` is on `PATH`, `install.sh` activates the `hyprland` tag: `fuzzel`, `waybar`,
`mako`, `hyprlock`, `hypridle`, `grim` and `slurp`, `brightnessctl`, and two portals, with their
configs under `dotfiles/.config/`. It does not install Hyprland itself. Machine-local settings,
such as monitors, scale, wallpaper, and `kb_layout`, go in `~/.config/hypr/local.conf`, which
`install.sh` creates empty. The main config sources it last, so a line there wins.

Three things GNOME does for free, which Hyprland does only when told. `hypridle` dims, locks,
and blanks the screen on a timer. The volume, mute, and brightness keys are bound to `wpctl` and
`brightnessctl`. GTK3 reads `dotfiles/.config/gtk-3.0/settings.ini` for the dark theme, because
no settings daemon runs.

`Super+x` opens a chord, as `C-x` does in Emacs and tmux. The next key runs one window command
and closes the chord, and waybar shows `C-x window` while it is open:

| Chord | Emacs | Hyprland |
| :--- | :--- | :--- |
| `Super+x 0` | `delete-window` | Close the window. |
| `Super+x 1` | `delete-other-windows` | Full screen. |
| `Super+x 2` | `split-window-below` | The next window opens under this one. |
| `Super+x 3` | `split-window-right` | The next window opens to the right. |
| `Super+x o` | `other-window` | Focus the next window. |
| `Escape`, `C-g` | `keyboard-quit` | Leave the chord. |

### Drop-down terminal

Ghostty's own quick terminal needs `wlr-layer-shell`, which Mutter does not implement, so on
GNOME `install.sh` installs the
[Quake Terminal](https://extensions.gnome.org/extension/6307/quake-terminal/) shell extension.
It drops down the Ghostty window that is already there. `install.sh` fetches the build that
matches the shell version and installs it with `gnome-extensions`; `cleanup.sh` removes it.

After the first install, log out and back in, because the shell loads a new extension at start
only. Then set the hotkey in the extension's preferences. `` Super+` `` works, because
`gnome-settings` clears the GNOME `switch-group` binding that would otherwise take it.
`gnome-settings` does not manage the extension's own keys.

Hyprland needs no extension. `hyprland.conf` starts one Ghostty window on the special workspace
`term`, and `` Super+` `` toggles that workspace over whatever is on screen.

### SSH agent

`.bashrc` points `SSH_AUTH_SOCK` at gpg-agent, but that covers login shells only. Graphical apps
read the systemd user environment, where the GNOME agent would claim the variable and never ask
the YubiKey. Three parts fix it: `dotfiles/.config/environment.d/10-gpg-ssh.conf` sets
`SSH_AUTH_SOCK` for the session, `install.sh` enables `gpg-agent-ssh.socket`, and `install.sh`
masks the GNOME SSH agent. Log out and back in after the first install.

HTTPS git remotes use `git-credential-libsecret` when the helper is present, not a cleartext
`~/.git-credentials`.

### Arch upkeep

`install.sh` installs `pacman-contrib` and enables `paccache.timer` for a weekly cache trim. The
aliases wrap the rest:

| Alias | Command | Why |
| :--- | :--- | :--- |
| `pacup` | `checkupdates` | List updates without touching the sync database. |
| `pacnew` | `pacdiff` | Merge the `.pacnew` files an upgrade leaves behind. |
| `paccleanup` | `paccache -rk2` | Trim the package cache by hand. |
| `pacorphans` | `pacman -Qtdq` | List orphaned dependencies. |

`install.sh` and the `setup-*.sh` scripts run `pacman -Syu` before they install. A plain `-S`
asks the mirrors for the versions the local database lists, and a stale database gets 404 from
every mirror. So an install is also an upgrade. `dotfiles/.makepkg.conf` builds AUR packages with every
core and skips package compression.
