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
1. **Install packages** via the detected manager (brew / apt / yay / pacman / dnf): `eza`, `fd`, `ripgrep`, `fzf`, `git-delta`, `zellij` (Arch/brew only — Debian and Fedora lack a package), plus [OpenCode](https://opencode.ai) and [Ghostty](https://ghostty.org) (best-effort).
2. Symlink configuration files (`.bashrc`, `.vimrc`, etc.) to your home directory.
3. Symlink scripts from `bin/` to `$HOME/bin`.
4. Install the vendored **0xProto Nerd Font** from `general/0xProto/`.
5. **Configure GPG Agent** for SSH support and YubiKey usage (detects OS and pinentry).
6. **Install Git Hooks** to prevent committing unencrypted secrets.

Flags and safety:

* `./install.sh /some/dir` — **probe run**: file layout only; skips packages, git config, and all GPG keyring/agent changes. Use to test changes safely.
* It **refuses to run** if a different dotfiles checkout already owns `~/.dotfiles`; `-f` overrides.
* After install, run `opencode auth login` once to connect a model provider.

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

Shared package-manager logic lives in `lib/pkg.sh`; shell init written by these scripts goes to
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
sudo pacman -S --needed gnupg pcsc-tools
sudo systemctl enable --now pcscd.service
```

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
setup — see `quick-terminal.conf`).

---
