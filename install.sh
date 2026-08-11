#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Personal dotfiles installer — macOS, Debian, Arch (omarchy), Fedora.
#
# Usage: ./install.sh [-f] [target-dir]
#
# A non-$HOME target is a probe run: file layout only, all live-state steps
# (git --global, GPG keyring/agent, packages) are skipped.
# =============================================================================

# -----------------------------
# Options & target directory
# -----------------------------
FORCE=0
while getopts ":f" opt; do
    case "$opt" in
        f)  FORCE=1 ;;
        \?) echo "Usage: $0 [-f] [target-dir]" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

TARGET_DIR="${1:-$HOME}"
TARGET_DIR="${TARGET_DIR%/}"           # normalise trailing slash so the $HOME test holds
[ -z "$TARGET_DIR" ] && TARGET_DIR="/"

# Live-state steps run only for a real home install
IS_HOME_INSTALL=0
[ "$TARGET_DIR" = "$HOME" ] && IS_HOME_INSTALL=1

# Dev containers get symlinks and config only — no packages, fonts, or apps
IN_CONTAINER=0
if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${CONTAINER_ID:-}" ] || [ -n "${CODESPACES:-}" ] || [ -f /.dockerenv ]; then
    IN_CONTAINER=1
fi

# -----------------------------
# Absolute path to this script
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN_DIR="$SCRIPT_DIR/bin"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"

# -----------------------------
# Guard: refuse to install over a different dotfiles checkout
# -----------------------------
EXISTING_DOTFILES="$HOME/.dotfiles"
SELF_DIR="$(cd "$SCRIPT_DIR" && pwd -P)"
OTHER_DIR="$(cd "$EXISTING_DOTFILES" 2>/dev/null && pwd -P || true)"

if [ "$IS_HOME_INSTALL" -eq 1 ] \
   && [ -n "$OTHER_DIR" ] \
   && [ "$OTHER_DIR" != "$SELF_DIR" ] \
   && [ "$FORCE" -ne 1 ]; then
    echo "Dotfiles already present at $EXISTING_DOTFILES — refusing to install." >&2
    echo "Run with -f to force." >&2
    exit 1
fi

# -----------------------------
# Package manager detection
# -----------------------------
# Prefer the native manager over linuxbrew, and yay over pacman on Arch.
# yay must not run under sudo (it escalates itself), hence per-manager sudo.
__detect_pkg_mgr() {
    if [[ "$OSTYPE" == darwin* ]] && command -v brew >/dev/null 2>&1; then
        echo brew; return
    fi
    if command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v yay >/dev/null 2>&1; then echo yay
    elif command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    elif command -v brew >/dev/null 2>&1; then echo brew
    else echo none
    fi
}

# Map a tool name to this manager's package name
__pkg_name() {
    local mgr=$1 tool=$2
    case "$mgr:$tool" in
        brew:fd)              echo "fd" ;;
        apt:fd|dnf:fd)        echo "fd-find" ;;
        *:fd)                 echo "fd" ;;
        brew:bash-completion) echo "bash-completion@2" ;;
        *:bash-completion)    echo "bash-completion" ;;
        brew:pinentry)        echo "pinentry-mac" ;;
        apt:pinentry)         echo "pinentry-gnome3" ;;
        *:pinentry)           echo "pinentry" ;;
        dnf:gnupg)            echo "gnupg2" ;;
        *)                    echo "$tool" ;;
    esac
}

# Best-effort: one missing package must not sink the rest
__pkg_install() {
    local mgr=$1; shift
    local tool pkg failed=""
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 && continue
        pkg="$(__pkg_name "$mgr" "$tool")"
        echo "  -> Installing $pkg ($mgr)"
        case "$mgr" in
            brew)   brew install "$pkg" || failed="$failed $tool" ;;
            apt)    sudo apt-get install -y "$pkg" || failed="$failed $tool" ;;
            yay)    yay -S --needed --noconfirm "$pkg" || failed="$failed $tool" ;;
            pacman) sudo pacman -S --needed --noconfirm "$pkg" || failed="$failed $tool" ;;
            dnf)    sudo dnf install -y "$pkg" || failed="$failed $tool" ;;
            *)      failed="$failed $tool" ;;
        esac
    done
    if [ -n "$failed" ]; then
        echo "Warning: could not install:$failed — install manually." >&2
    fi
}

PKG_MGR="$(__detect_pkg_mgr)"

if [ "$IN_CONTAINER" -eq 1 ]; then
    echo "[container] Skipping package installation."
elif [ "$IS_HOME_INSTALL" -eq 1 ] && [ "$PKG_MGR" != "none" ]; then
    echo "Installing packages via $PKG_MGR..."
    if [ "$PKG_MGR" = "apt" ]; then
        sudo apt-get update || echo "Warning: apt-get update failed." >&2
    fi
    __pkg_install "$PKG_MGR" eza fzf zellij gnupg
    command -v rg >/dev/null 2>&1     || __pkg_install "$PKG_MGR" ripgrep
    command -v delta >/dev/null 2>&1  || __pkg_install "$PKG_MGR" git-delta
    command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1 \
        || __pkg_install "$PKG_MGR" fd
    __pkg_install "$PKG_MGR" bash-completion pinentry
elif [ "$IS_HOME_INSTALL" -eq 0 ]; then
    echo "[probe] Skipping package installation."
else
    echo "Warning: no supported package manager found — skipping packages." >&2
fi

# -----------------------------
# Sync dotfiles via Python
# -----------------------------
echo "Syncing dotfiles to $TARGET_DIR..."
if ! python3 "$SCRIPT_DIR/bin/sync-dotfiles" "$TARGET_DIR"; then
    echo "Error: sync-dotfiles failed. Aborting."
    exit 1
fi

# -----------------------------
# Create dotfiles alias
# -----------------------------
BASHRC_D_DIR="$TARGET_DIR/.bashrc.d"
ALIAS_FILE="$BASHRC_D_DIR/dotfiles_alias"

mkdir -p "$BASHRC_D_DIR"

echo "Creating dotfiles alias at '$ALIAS_FILE'."
cat <<EOF > "$ALIAS_FILE"
# Alias to quickly jump to dotfiles directory
alias dotfiles='cd $SCRIPT_DIR'
EOF

echo "Done. '$ALIAS_FILE' created."

# -----------------------------
# Sync custom scripts
# -----------------------------
TARGET_BIN_DIR="$TARGET_DIR/bin"

echo "Syncing custom scripts to $TARGET_BIN_DIR..."

mkdir -p "$TARGET_BIN_DIR"
# Loop through all files in the source bin directory
for script_path in "$SOURCE_BIN_DIR"/*; do
    # Check if the glob found any files
    if [ -e "$script_path" ]; then
        script_name=$(basename "$script_path")
        target_path="$TARGET_BIN_DIR/$script_name"

        # Make the source script executable before linking
        chmod +x "$script_path"

        echo "  -> Linking $script_name"
        # Create or update the symlink, forcing overwrite
        ln -sf "$script_path" "$target_path"
    fi
done

# -----------------------------
# Install Starship (Prompt)
# -----------------------------
if ! command -v starship >/dev/null; then
    echo "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$TARGET_DIR/bin"
fi

# -----------------------------
# Fonts (0xProto Nerd Font, vendored in general/)
# -----------------------------
if [[ "$OSTYPE" == darwin* ]]; then
    FONT_DIR="$TARGET_DIR/Library/Fonts"
else
    FONT_DIR="$TARGET_DIR/.local/share/fonts"
fi

if [ "$IN_CONTAINER" -eq 1 ]; then
    echo "[container] Skipping font installation (fonts render on the host)."
else
    echo "Installing 0xProto Nerd Font to $FONT_DIR..."
    mkdir -p "$FONT_DIR"
    cp "$SCRIPT_DIR"/general/0xProto/*.ttf "$FONT_DIR/"
fi

if [ "$IS_HOME_INSTALL" -eq 1 ] && [ "$IN_CONTAINER" -eq 0 ] && [[ "$OSTYPE" != darwin* ]] && command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$FONT_DIR"
fi

# -----------------------------
# Git configuration  (live state — home installs only)
# -----------------------------
if [ "$IS_HOME_INSTALL" -eq 0 ]; then
    echo "[probe] Skipping global git configuration."
elif command -v git &> /dev/null; then
    echo "Configuring global Git settings..."

    git config --global user.name "Ishmael Aqsar"
    git config --global user.email "ishmael-dev@aqsar.dev"
    git config --global core.excludesfile "$HOME/.gitignore_global"
    git config --global core.attributesfile "$HOME/.gitattributes"

    echo "Git configuration complete."
else
    echo "Git not found. Skipping git configuration."
fi

# -----------------------------
# GPG Agent Configuration
# -----------------------------
# agent.conf is a plain file write; the agent reload and keyring import below
# are live state (gpg reads GNUPGHOME, not GNUPG_DIR) and gated on home installs.
echo "Configuring GPG Agent..."

GNUPG_DIR="$TARGET_DIR/.gnupg"
mkdir -p "$GNUPG_DIR"
chmod 700 "$GNUPG_DIR"

PINENTRY_PATH=""

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: Look for Homebrew pinentry-mac
    if command -v pinentry-mac >/dev/null; then
        PINENTRY_PATH=$(command -v pinentry-mac)
    elif [ -f "/opt/homebrew/bin/pinentry-mac" ]; then
        PINENTRY_PATH="/opt/homebrew/bin/pinentry-mac"
    elif [ -f "/usr/local/bin/pinentry-mac" ]; then
        PINENTRY_PATH="/usr/local/bin/pinentry-mac"
    else
        echo "Warning: pinentry-mac not found. Please run: brew install pinentry-mac"
    fi
else
    # Linux: Try standard pinentries in order of preference
    # We prefer GUI (gnome3/qt) if available, falling back to curses/tty
    if command -v pinentry-gnome3 >/dev/null; then
        PINENTRY_PATH=$(command -v pinentry-gnome3)
    elif command -v pinentry-qt >/dev/null; then
        PINENTRY_PATH=$(command -v pinentry-qt)
    elif command -v pinentry-curses >/dev/null; then
        PINENTRY_PATH=$(command -v pinentry-curses)
    else
        # Fallback to generic link
        PINENTRY_PATH="/usr/bin/pinentry"
    fi
fi

AGENT_CONF="$GNUPG_DIR/gpg-agent.conf"
echo "Writing gpg-agent.conf to $AGENT_CONF..."

cat <<EOF > "$AGENT_CONF"
# ---------------------------------------------------------
# GPG Agent Configuration (Generated by dotfiles/install)
# ---------------------------------------------------------

# Enable SSH support so YubiKey works for SSH auth
enable-ssh-support

# Cache PIN for 1 day (86400 seconds)
default-cache-ttl 86400
max-cache-ttl 86400

# Cache SSH keys for 1 day as well
default-cache-ttl-ssh 86400
max-cache-ttl-ssh 86400

# Pinentry Program detected by install script
EOF

if [ -n "$PINENTRY_PATH" ]; then
    echo "pinentry-program $PINENTRY_PATH" >> "$AGENT_CONF"
    echo "  -> Set pinentry to $PINENTRY_PATH"
else
    echo "# WARNING: No specific pinentry-program found during install" >> "$AGENT_CONF"
    echo "  -> Warning: Could not detect pinentry program."
fi

if [ "$IS_HOME_INSTALL" -eq 0 ]; then
    echo "[probe] Skipping gpg-agent reload and key import."
else
    if command -v gpg-connect-agent >/dev/null; then
        echo "Reloading gpg-agent..."
        gpg-connect-agent reloadagent /bye
    fi

    # -----------------------------
    # Import Public Key (Bootstrapping)
    # -----------------------------
    # If a public key is found in dotfiles/public.asc, this auto-imports it.
    # Command to generate: gpg --armor --export $KEYID > dotfiles/public.asc

    PUB_KEY="$DOTFILES_DIR/public.asc"
    if ! command -v gpg >/dev/null 2>&1; then
        echo "gpg not found. Skipping GPG import."
    elif [ -f "$PUB_KEY" ]; then
        echo "Importing public GPG key from $PUB_KEY..."
        gpg --import "$PUB_KEY"

        # This extracts the fingerprint and sets it to ultimate trust.
        FINGERPRINT=$(gpg --with-colons --import-options show-only --import "$PUB_KEY" \
            | grep -m 1 "^fpr" | awk -F: '{print $10}')

        if [ -n "$FINGERPRINT" ]; then
            echo "Setting ultimate trust for $FINGERPRINT..."
            echo -e "5\ny\n" | gpg --command-fd 0 --expert --edit-key "$FINGERPRINT" trust >/dev/null 2>&1
        fi
    else
        echo "No public.asc found in dotfiles. Skipping GPG import."
    fi
fi

# -----------------------------
# OpenCode (terminal agent)
# -----------------------------
if [ "$IS_HOME_INSTALL" -eq 0 ] || [ "$IN_CONTAINER" -eq 1 ]; then
    echo "Skipping OpenCode installation."
elif ! command -v opencode >/dev/null 2>&1; then
    echo "Installing OpenCode..."
    case "$PKG_MGR" in
        brew)   brew install anomalyco/tap/opencode || echo "Warning: OpenCode install failed." >&2 ;;
        yay)    yay -S --needed --noconfirm opencode || echo "Warning: OpenCode install failed." >&2 ;;
        pacman) sudo pacman -S --needed --noconfirm opencode || echo "Warning: OpenCode install failed." >&2 ;;
        *)      curl -fsSL https://opencode.ai/install | bash || echo "Warning: OpenCode install failed." >&2 ;;
    esac
fi

if [ "$IS_HOME_INSTALL" -eq 1 ] && [ "$IN_CONTAINER" -eq 0 ]; then
    echo "NOTE: run 'opencode auth login' to connect a model provider (interactive, not scripted here)."
fi

# -----------------------------
# Ghostty (terminal emulator) — best-effort
# -----------------------------
# No Debian package, Fedora needs a COPR; the config is harmless without Ghostty.
if [ "$IS_HOME_INSTALL" -eq 0 ] || [ "$IN_CONTAINER" -eq 1 ]; then
    echo "Skipping Ghostty installation."
elif ! command -v ghostty >/dev/null 2>&1; then
    echo "Installing Ghostty..."
    case "$PKG_MGR" in
        brew)   brew install --cask ghostty || echo "Warning: Ghostty install failed." >&2 ;;
        yay)    yay -S --needed --noconfirm ghostty || echo "Warning: Ghostty install failed." >&2 ;;
        pacman) sudo pacman -S --needed --noconfirm ghostty || echo "Warning: Ghostty install failed." >&2 ;;
        dnf)    echo "Ghostty is not in Fedora's base repos — enable a COPR manually (skipping)." ;;
        *)      echo "No Ghostty package for this platform — install manually (skipping)." ;;
    esac
fi

# Quick-terminal opt-in: auto-enabled on macOS only; Linux needs compositor
# setup first (see dotfiles/.config/ghostty/quick-terminal.conf).
GHOSTTY_TARGET_DIR="$TARGET_DIR/.config/ghostty"
if [[ "$OSTYPE" == darwin* ]] && [ -d "$GHOSTTY_TARGET_DIR" ] && [ ! -e "$GHOSTTY_TARGET_DIR/config.local" ]; then
    echo "Enabling Ghostty quick terminal (macOS)..."
    cat <<'EOF' > "$GHOSTTY_TARGET_DIR/config.local"
# Machine-local Ghostty overrides — not tracked by the dotfiles repo.
config-file = quick-terminal.conf
EOF
fi

# -----------------------------
# Secrets Pre-commit Hook
# -----------------------------
# Installs the git hook to prevent committing unencrypted secrets
HOOK_PATH="$SCRIPT_DIR/.git/hooks/pre-commit"

if [ -d "$SCRIPT_DIR/.git" ]; then
    echo "Installing secrets pre-commit hook at $HOOK_PATH..."
    # Ensure hooks directory exists
    mkdir -p "$(dirname "$HOOK_PATH")"

    cat <<'EOF' > "$HOOK_PATH"
#!/usr/bin/env bash
# Pre-commit hook to ensure no unencrypted secrets are committed

REPO_ROOT="$(git rev-parse --show-toplevel)"
MANAGE_SECRETS="$REPO_ROOT/bin/manage-secrets"

if [ -x "$MANAGE_SECRETS" ]; then
    python3 "$MANAGE_SECRETS" verify
else
    echo "Warning: bin/manage-secrets not found or not executable. Skipping verification."
fi
EOF

    chmod +x "$HOOK_PATH"
    echo "Hook installed."
else
    echo "Skipping hook installation (.git directory not found)."
fi

echo "Dotfiles installation complete."
