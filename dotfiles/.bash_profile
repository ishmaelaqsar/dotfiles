# ============================================================
# Load Global Profile
# ============================================================

if [[ -f /etc/profile ]]; then
    . /etc/profile
fi

# ============================================================
# PATH Management
# ============================================================

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

# Clean up helper
unset -f __add_path

# ============================================================
# Source Helper Functions
# ============================================================
if [[ -f ~/.helpers ]]; then
    . ~/.helpers
fi

# ============================================================
# Environment & One-Time Setup
# ============================================================

# Run these commands only when running in a container
if [[ -v CONTAINER_ID ]] || [[ -n "$REMOTE_CONTAINERS" ]]; then
    export LC_ALL=en_US.utf8
fi

export IDENTITY="Ishmael Aqsar <ishmael-dev@aqsar.dev>"
export VM_USER="ishmael"

# Local workspace
if [[ ! -d ~/workspace ]]; then
    mkdir ~/workspace
fi
export WORKSPACE="$HOME/workspace"

# ------------------------------------------------------------
# Editor Configuration (VS Code + Vi)
# ------------------------------------------------------------
export EDITOR='vi'

# "code" is the VS Code CLI. --wait is required for git commits.
if command -v code >/dev/null 2>&1; then
    export VISUAL='code --wait'
    export GIT_EDITOR='code --wait'
else
    export VISUAL="$EDITOR"
fi

export GIT_OPEN="$VISUAL"

# ============================================================
# Load User .bashrc (for interactive shells)
# ============================================================

if [[ -n "$BASH_VERSION" ]]; then
    if [[ -f "$HOME/.bashrc" ]]; then
        . "$HOME/.bashrc"
    fi
fi
