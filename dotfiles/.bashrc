# ============================================================
# Bash Prompt with Git Branch & Jobs
# ============================================================

# Color definitions
RED="\[\033[0;91m\]"
GREEN="\[\033[0;92m\]"
YELLOW="\[\033[0;93m\]"
BLUE="\[\033[0;94m\]"
MAGENTA="\[\033[0;95m\]"
CYAN="\[\033[0;96m\]"
WHITE="\[\033[1;37m\]"
BOLD="\[\033[1m\]"
RESET="\[\033[0m\]"

# Git branch helper (with dirty indicator)
git_branch() {
    local branch dirty
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return
    dirty=$(git status --porcelain 2>/dev/null)
    if [[ -n "$branch" ]]; then
        if [[ -n "$dirty" ]]; then
             echo "(${branch}${RED}*${MAGENTA})"
        else
            echo "(${branch})"
        fi
    fi
}

# Prompt setup
set_prompt() {
    local git_info jobs_info venv_info
    git_info=$(git_branch)

    # 1. Check for Virtual Env
    if [[ -n "$VIRTUAL_ENV" ]]; then
        # Extracts the folder name (e.g., .venv) and colors it Cyan
        venv_info="${BOLD}${CYAN}($(basename "$VIRTUAL_ENV"))${RESET} "
    else
        venv_info=""
    fi

    # Only show Jobs= if there are background jobs
    if [[ $(jobs -p | wc -l) -gt 0 ]]; then
        jobs_info="Jobs=${BOLD}${YELLOW}\j${RESET} "
    else
        jobs_info=""
    fi

    # Construct PS1
    PS1="${venv_info}"

    # User (Green) @ (White) Host (Light Blue)
    PS1+="${BOLD}${GREEN}\u${RESET}${WHITE}@${RESET}${BOLD}${BLUE}\h${RESET} "

    PS1+="${jobs_info}"

    # Current Working Directory (Cyan)
    PS1+="${BOLD}${CYAN}\w${RESET} "

    # Git Branch (Magenta)
    PS1+="${BOLD}${MAGENTA}${git_info}${RESET} \$ "
}

# Assign to PROMPT_COMMAND so it updates dynamically
PROMPT_COMMAND=set_prompt

# ============================================================
# Environment & Basic Setup
# ============================================================

# Source aliases
if [[ -f ~/.aliases ]]; then
    . ~/.aliases
fi

# Local workspace (Alias ONLY)
alias ws='cd "$WORKSPACE"'

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

# Eat shell integration
[[ -n "$EAT_SHELL_INTEGRATION_DIR" ]] && \
    source "$EAT_SHELL_INTEGRATION_DIR/bash"
