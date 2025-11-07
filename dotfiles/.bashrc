# ============================================================
# Bash Prompt with Git Branch & Jobs
# ============================================================

# Color definitions
RED="\[\033[0;31m\]"
GREEN="\[\033[0;32m\]"
YELLOW="\[\033[0;33m\]"
BLUE="\[\033[0;34m\]"
MAGENTA="\[\033[0;35m\]"
CYAN="\[\033[0;36m\]"
BOLD="\[\033[1m\]"
RESET="\[\033[0m\]"

# Git branch helper (with dirty indicator)
git_branch() {
    local branch dirty
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return
    dirty=$(git status --porcelain 2>/dev/null)
    if [[ -n "$branch" ]]; then
        if [[ -n "$dirty" ]]; then
            echo "(${branch}*)"
        else
            echo "(${branch})"
        fi
    fi
}

# Prompt setup
set_prompt() {
    local git_info jobs_info
    git_info=$(git_branch)

    # Only show Jobs= if there are background jobs
    if [[ $(jobs -p | wc -l) -gt 0 ]]; then
        jobs_info="Jobs=${BOLD}${YELLOW}\j${RESET} "
    else
        jobs_info=""
    fi

    # Construct PS1
    PS1="${BOLD}${GREEN}\u${RESET}@${BOLD}${BLUE}\h${RESET} "  # user@host
    PS1+="${jobs_info}"                                        # conditional jobs
    PS1+="${BOLD}${CYAN}\w${RESET} "                           # current working directory
    PS1+="${BOLD}${MAGENTA}${git_info}${RESET} \$ "            # git branch and prompt char
}

# Assign to PROMPT_COMMAND so it updates dynamically
PROMPT_COMMAND=set_prompt


# ============================================================
# Environment & Basic Setup
# ============================================================

# Source general helper functions
if [[ -f ~/.helpers ]]; then
    . ~/.helpers
fi

# Run these commands only when running in a container
if [[ -v CONTAINER_ID ]]; then
    export LC_ALL=en_US.utf8
fi

# Source aliases
if [[ -f ~/.aliases ]]; then
    . ~/.aliases
fi

# Source venv helpers
if [[ -f ~/.venv_helpers ]]; then
    . ~/.venv_helpers
fi

# Local workspace
if [[ ! -d ~/workspace ]]; then
    mkdir ~/workspace
fi
export WORKSPACE="$HOME/workspace"
alias ws='cd "$WORKSPACE"'

# ============================================================
# Editor Configuration
# ============================================================

if command -v emacs >/dev/null 2>&1; then
    export EDITOR='emacs -nw'
    # Start emacs daemon if not already running
    if ! pgrep -a emacs | grep daemon >/dev/null 2>&1; then
        emacs --daemon --chdir="$WORKSPACE"
    fi
    alias e='emacsclient -nw'
    alias emacs='emacsclient -nw'
else
    export EDITOR='nano'
fi

export GIT_OPEN="$EDITOR"
export VISUAL="$EDITOR"

# ============================================================
# Perl / CPAN Setup
# ============================================================

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
