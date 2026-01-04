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
if [[ -v CONTAINER_ID ]]; then
    export LC_ALL=en_US.utf8
fi

export IDENTITY="Ishmael Aqsar <ishmael-dev@aqsar.dev>"

export VM_USER="ishmael"

# Local workspace
if [[ ! -d ~/workspace ]]; then
    mkdir ~/workspace
fi
export WORKSPACE="$HOME/workspace"

# Editor Configuration
if command -v emacs >/dev/null 2>&1; then
    export EDITOR='emacs -nw'
    # Start emacs daemon if not already running
    if ! pgrep -a emacs | grep daemon >/dev/null 2>&1; then
        emacs --daemon --chdir="$WORKSPACE"
    fi
else
    export EDITOR='nano'
fi

export GIT_OPEN="$EDITOR"
export VISUAL="$EDITOR"

# Perl / CPAN Setup
if command -v cpanm >/dev/null 2>&1; then
    if __has_internet; then
        if cpanm --local-lib=~/perl5 local::lib >/dev/null 2>&1; then
            eval "$(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)"
        fi
    else
        echo "Skipping cpan local::lib setup (no internet connection)."
    fi
fi

# ============================================================
# Load User .bashrc (for interactive shells)
# ============================================================

if [[ -n "$BASH_VERSION" ]]; then
    if [[ -f "$HOME/.bashrc" ]]; then
        . "$HOME/.bashrc"
    fi
fi
