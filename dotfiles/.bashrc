# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================================
# Starship Prompt
# ============================================================

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    PS1='\u@\h:\w\$ '
fi

# ============================================================
# History
# ============================================================

# ignoreboth is ignorespace plus ignoredups. A command that starts with a space
# stays out of the file, which matters for anything that carries a secret.
export HISTCONTROL=ignoreboth
export HISTSIZE=10000
export HISTFILESIZE=20000

# Keep a value out of the file even when the leading space is forgotten.
export HISTIGNORE='add_secret *:manage-secrets encrypt *:* --password *:* --token *'

# Append instead of overwrite, so two shells do not lose each other's history.
shopt -s histappend

# ============================================================
# Environment & Basic Setup
# ============================================================

# Source aliases
if [[ -f ~/.aliases ]]; then
    . ~/.aliases
fi

# Source Helper Functions
if [[ -f ~/.helpers ]]; then
    . ~/.helpers
fi

# Local workspace. .bash_profile exports WORKSPACE, and install.sh creates the
# directory, so this only adds the shortcut.
if [[ -d "${WORKSPACE:-}" ]]; then
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
    # Only export a socket that gpgconf named. An empty value leaves ssh with
    # no agent and no error.
    __gpg_ssh_sock=$(gpgconf --list-dirs agent-ssh-socket 2>/dev/null)
    if [ -n "$__gpg_ssh_sock" ]; then
        export SSH_AUTH_SOCK="$__gpg_ssh_sock"
    else
        echo "gpg-agent named no ssh socket; ssh has no agent." >&2
    fi
    unset __gpg_ssh_sock
fi

# Tell a running agent which terminal to draw the PIN prompt on. The test
# matters: this call starts the agent when none runs, and the start probes the
# card reader, which blocks a new shell for several seconds when no card is in.
# A cold agent does not need the call anyway — the first gpg command starts it
# with GPG_TTY already exported above.
if [[ -S "$(gpgconf --list-dirs agent-socket 2>/dev/null)" ]]; then
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
fi

# -----------------------------------------------------------------------------
# YubiKey subkey expiry
# -----------------------------------------------------------------------------

# Once a day, in the first shell of the day: is a YubiKey subkey close to its
# expiry? yk prints nothing when all is well, so this costs output only when
# maintenance is due. The stamp keeps it to one run per day, and `find -mtime
# +0` is true when the stamp is more than 24 hours old on both find variants.
if command -v yk >/dev/null 2>&1 && [[ -f "${YK_PUBKEY:-}" ]]; then
    __yk_stamp="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/yk-remind"
    if [[ ! -f "$__yk_stamp" || -n "$(find "$__yk_stamp" -mtime +0 2>/dev/null)" ]]; then
        mkdir -p "${__yk_stamp%/*}" && touch "$__yk_stamp"
        # remind exits 1 when it has something to say. That must not leak out.
        yk remind || true
    fi
    unset __yk_stamp
fi

# ============================================================
# Shell Completion Setup
# ============================================================

if ! shopt -oq posix; then
    if [[ -f /opt/homebrew/etc/bash_completion ]]; then
        . /opt/homebrew/etc/bash_completion
    elif [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    fi
fi

# kubectl completion
if command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion bash)
fi

# podman completion. bin/docker is a shell script that runs podman, so the
# same completer serves `docker`. head reads the first lines of the shim, and
# never scans a binary.
if command -v podman >/dev/null 2>&1; then
    source <(podman completion bash)
    __docker_bin="$(command -v docker)"
    if [[ -n "$__docker_bin" ]] && head -c 512 "$__docker_bin" | grep -q podman; then
        complete -o default -F __start_podman docker
    fi
    unset __docker_bin
fi

# FNM setup
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
    source <(fnm completions --shell bash)
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
