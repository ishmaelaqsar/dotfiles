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

# The gcloud SDK tarball installs under $HOME. A package install puts gcloud in
# a system directory instead, and this line then finds nothing.
__add_path "$HOME/google-cloud-sdk/bin"

# Clean up helper
unset -f __add_path

# ============================================================
# Environment & One-Time Setup
# ============================================================

# Run these commands only when running in a container. -n with a default,
# not -v: /bin/bash on macOS is 3.2, and its parser rejects -v, which kills
# the rest of this file. The locale name must exist, or every program
# complains: macOS spells it en_US.UTF-8, and a slim container often has
# only C.UTF-8.
if [[ -n "${CONTAINER_ID:-}" ]] || [[ -n "${REMOTE_CONTAINERS:-}" ]]; then
    if locale -a 2>/dev/null | grep -qix 'en_US.UTF-8'; then
        export LC_ALL=en_US.UTF-8
    elif locale -a 2>/dev/null | grep -qix 'C.UTF-8'; then
        export LC_ALL=C.UTF-8
    fi
fi

export IDENTITY="Ishmael Aqsar <ishmael-dev@aqsar.dev>"

# The public key of the YubiKey identity. sync-dotfiles links it here from
# dotfiles/public.asc. yk reads the expiry dates from it, so `yk status` and
# `yk remind` need no argument.
export YK_PUBKEY="$HOME/public.asc"
export VM_USER="ishmael"

# Second brain vault — defaults to ~/vault (.helpers); override per machine:
# export OBSIDIAN_VAULT="$HOME/some/other/vault"

# Org notes. Outside the vault, which stays markdown for Obsidian.
export ORG_DIR="$HOME/org"

# Local workspace. install.sh creates the directory: a login shell reads its
# configuration, and does not build the home directory.
export WORKSPACE="$HOME/workspace"

# podman's API socket, for lazydocker and every docker Go client; podman
# itself needs nothing. Linux: the rootless socket that podman.socket creates
# at login. macOS: the link that `podman machine start` publishes, which
# dangles while the VM is off, so -S fails and DOCKER_HOST stays unset.
for __podman_sock in \
    "${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/containers/podman/machine/podman.sock"; do
    if [[ -S "$__podman_sock" ]]; then
        export DOCKER_HOST="unix://$__podman_sock"
        break
    fi
done
unset __podman_sock

# ------------------------------------------------------------
# Editor: emacsclient, then a plain emacs, then vi
# ------------------------------------------------------------
# emacsclient needs a running Emacs. -t opens in the terminal, -c a new frame,
# and --alternate-editor= (empty value) starts a daemon when none runs, so a
# git commit never hangs on a missing server. The long flag, not -a '': a
# consumer that splits EDITOR on whitespace turns '' into two literal
# apostrophes. A machine with emacs but no client (a minimal install) gets
# emacs -nw -q, and a machine with no Emacs at all keeps vi.
if command -v emacsclient >/dev/null 2>&1; then
    export EDITOR='emacsclient -t --alternate-editor='
    export VISUAL='emacsclient -c --alternate-editor='
elif command -v emacs >/dev/null 2>&1; then
    export EDITOR='emacs -nw -q'
    export VISUAL="$EDITOR"
else
    export EDITOR='vi'
    export VISUAL="$EDITOR"
fi
export GIT_EDITOR="$EDITOR"


# ============================================================
# Load User .bashrc (for interactive shells)
# ============================================================

if [[ -n "$BASH_VERSION" ]]; then
    if [[ -f "$HOME/.bashrc" ]]; then
        . "$HOME/.bashrc"
    fi
fi
