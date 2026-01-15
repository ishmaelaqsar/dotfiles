# ============================================================
# Starship Prompt
# ============================================================

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    PS1='\u@\h:\w\$ '
fi

# ============================================================
# Environment & Basic Setup
# ============================================================

# Source aliases
if [[ -f ~/.aliases ]]; then
    . ~/.aliases
fi

# Local workspace
if [[ -d ~/workspace ]]; then
    export WORKSPACE="$HOME/workspace"
    alias ws='cd "$WORKSPACE"'
fi

# -----------------------------------------------------------------------------
# GPG & SSH Agent Integration
# -----------------------------------------------------------------------------

# This tells GPG which terminal to draw the PIN prompt on.
export GPG_TTY=$(tty)

# Link SSH to GPG
unset SSH_AGENT_PID
if command -v gpgconf >/dev/null; then
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
fi

# Ensures the agent knows about the current TTY immediately on shell startup.
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1

# ============================================================
# Shell Completion Setup
# ============================================================

if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    fi
fi

# kubectl completion
if command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion bash)
fi

# podman completion
if command -v podman >/dev/null 2>&1; then
    source <(podman completion bash)
fi

# ============================================================
# User-Specific Extensions
# ============================================================

if [[ -d ~/.bashrc.d ]]; then
    for rc in ~/.bashrc.d/*; do
        [[ -r "$rc" ]] && . "$rc"
    done
fi
unset rc

