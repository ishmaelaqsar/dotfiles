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
1. Symlink configuration files (`.bashrc`, `.vimrc`, etc.) to your home directory.
2. Symlink scripts from `bin/` to `$HOME/bin`.
3. **Configure GPG Agent** for SSH support and YubiKey usage (detects OS and pinentry).
4. **Install Git Hooks** to prevent committing unencrypted secrets.

---

## Editor Configuration

* **Visual Editor:** VS Code (`code --wait`).
    * Used for git commits, merges, and complex editing when available.
* **Terminal Editor:** Vi / Vim.
    * Used for quick edits in the terminal.
    * Includes a minimal `.vimrc` for syntax highlighting and standard behavior.

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
Add the helpers to your shell (already done if you source `.bash_profile`):

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
