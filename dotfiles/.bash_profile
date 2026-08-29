# ============================================================
# Load Global Profile
# ============================================================

if [[ -f /etc/profile ]]; then
    . /etc/profile
fi

# ============================================================
# PATH Management
# ============================================================

# Find /opt/homebrew/bin/bash before /bin/bash (no-op on Linux)
if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# Helper to prepend to PATH if not already present
__add_path() {
    local dir="$1"
    if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
        PATH="$dir:$PATH"
    fi
}

# Add user bin directories
__add_path "$HOME/bin"
__add_path "$HOME/.local/bin"
__add_path "$HOME/.cargo/bin"
__add_path "$HOME/go/bin"

# Clean up helper
unset -f __add_path

# ============================================================
# Environment & One-Time Setup
# ============================================================

# Run these commands only when running in a container
if [[ -v CONTAINER_ID ]] || [[ -n "$REMOTE_CONTAINERS" ]]; then
    export LC_ALL=en_US.utf8
fi

export IDENTITY="Ishmael Aqsar <ishmael-dev@aqsar.dev>"

# The public key of the YubiKey identity. sync-dotfiles links it here from
# dotfiles/public.asc. yk reads the expiry dates from it, so `yk status` and
# `yk remind` need no argument.
export YK_PUBKEY="$HOME/public.asc"
export VM_USER="ishmael"

# Second brain vault — defaults to ~/vault (.helpers); override per machine:
# export OBSIDIAN_VAULT="$HOME/some/other/vault"

# Local workspace. install.sh creates the directory: a login shell reads its
# configuration, and does not build the home directory.
export WORKSPACE="$HOME/workspace"

# ------------------------------------------------------------
# Editor: Emacs where it is installed, then VS Code, then vi
# ------------------------------------------------------------
# emacsclient needs a running Emacs. -t opens in the terminal, -c a new frame,
# and -a '' starts a daemon when none runs, so a git commit never hangs on a
# missing server. "code --wait" is the VS Code CLI; --wait matters for git.
if command -v emacsclient >/dev/null 2>&1; then
    export EDITOR="emacsclient -t -a ''"
    export VISUAL="emacsclient -c -a ''"
    export GIT_EDITOR="$EDITOR"
elif command -v code >/dev/null 2>&1; then
    export EDITOR='vi'
    export VISUAL='code --wait'
    export GIT_EDITOR='code --wait'
else
    export EDITOR='vi'
    export VISUAL="$EDITOR"
fi


# lazygit looks in ~/Library/Application Support on macOS, and in ~/.config on
# Linux. Name the file, so one config serves both platforms.
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"

# ============================================================
# Load User .bashrc (for interactive shells)
# ============================================================

if [[ -n "$BASH_VERSION" ]]; then
    if [[ -f "$HOME/.bashrc" ]]; then
        . "$HOME/.bashrc"
    fi
fi
