# ============================================================
# Helper Functions
# ============================================================

# Check for internet connectivity
__has_internet() {
    ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 || \
    ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1 || \
    ping -c 1 -W 1 cpan.org >/dev/null 2>&1
}

# Detect git project root (fallback: current dir)
__get_project_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        pwd
    fi
}

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

# Run these commands only when running in a container
if [[ -v CONTAINER_ID ]]; then
    export LC_ALL=en_US.utf8
fi

# Source aliases
if [[ -f ~/.aliases ]]; then
    . ~/.aliases
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
# Python Virtual Environment Helpers
# ============================================================

# venv-init: create new virtual environment
# Usage: venv-init [-p python_executable] [dir] [--venv-options]
venv-init() {
    local venv_dir=".venv"
    local python_cmd="python3"
    local root="$(__get_project_root)"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--python)
                python_cmd="$2"
                shift 2
                ;;
            -*)
                # venv option, stop parsing positional args
                break
                ;;
            *)
                venv_dir="$1"
                shift
                ;;
        esac
    done

    local target="$root/$venv_dir"

    echo "Creating virtual environment at: $target using $python_cmd"
    "$python_cmd" -m venv "$target" "$@"

    if [[ $? -eq 0 ]]; then
        echo "Virtual environment created successfully."
    else
        echo "Failed to create virtual environment."
        return 1
    fi
}

# venv-start: activate existing environment
# Usage: venv-start [dir]
venv-start() {
    local venv_dir=".venv"
    local root="$(__get_project_root)"

    if [[ -n "$1" ]]; then
        venv_dir="$1"
    fi

    local target="$root/$venv_dir"

    if [[ -f "$target/bin/activate" ]]; then
        # shellcheck disable=SC1090
        source "$target/bin/activate"
        echo "Activated virtual environment: $target"
    else
        echo "No virtual environment found at: $target"
        echo "Run 'venv-init' first to create one."
        return 1
    fi
}

# venv-stop: deactivate current environment
venv-stop() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate
        echo "Virtual environment deactivated."
    else
        echo "No active virtual environment."
    fi
}

# venv-restart: convenience wrapper (stop + start)
venv-restart() {
    local arg="$1"
    venv-stop >/dev/null 2>&1
    venv-start "$arg"
}

# venv-path: print path of current or detected venv
venv-path() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "$VIRTUAL_ENV"
    else
        local root="$(__get_project_root)"
        if [[ -d "$root/.venv" ]]; then
            echo "$root/.venv"
        else
            echo "No virtual environment detected."
            return 1
        fi
    fi
}

# venv-list: list all virtual environments under a directory
# Shows name, path, Python version, and indicates if active
venv-list() {
    local search_dir="${1:-$WORKSPACE}"
    local found=0

    echo "Searching for virtual environments under: $search_dir"
    echo "-----------------------------------------------------"

    # Use process substitution to avoid subshell issues
    while read -r bin_dir; do
        local venv_dir
        venv_dir="$(dirname "$bin_dir")"

        local pyver
        if [[ -x "$bin_dir/python" ]]; then
            pyver="$("$bin_dir/python" -V 2>&1)"
        else
            pyver="Unknown"
        fi

        local marker=""
        if [[ "$VIRTUAL_ENV" == "$venv_dir" ]]; then
            marker="(active)"
        fi

        # Display: workspace_name -> venv_path [Python version] (active)
        echo "$(basename "$(dirname "$venv_dir")")  ->  $venv_dir  [$pyver] $marker"

        found=1
    done < <(find "$search_dir" -type d -name "bin" -path "*/.venv/bin" 2>/dev/null)

    if [[ $found -eq 0 ]]; then
        echo "No virtual environments found."
    fi
}


# venv-help: display usage information for venv helpers
venv-help() {
    cat <<'EOF'

Python Virtual Environment Helpers
==================================

Functions:

  venv-init [-p python_executable] [dir] [--venv-options]
      Create a new virtual environment.
      -p, --python   Specify Python interpreter (default: python3)
      dir            Optional directory name (default: .venv)
      Additional arguments are passed to python -m venv.

  venv-start [dir]
      Activate an existing virtual environment.
      dir            Optional directory name (default: .venv)

  venv-stop
      Deactivate the currently active virtual environment.

  venv-restart [dir]
      Stop and then start a virtual environment.

  venv-path
      Print the path of the currently active or detected virtual environment.

  venv-list [search_dir]
      List all virtual environments under search_dir (default: $WORKSPACE).
      Shows directory, Python version, and indicates if active.

  venv-help
      Prints this help information

Aliases:

  vinit      = venv-init
  vstart     = venv-start
  vstop      = venv-stop
  vrestart   = venv-restart
  vlist      = venv-list
  vhelp      = venv-help

Examples:

  vinit -p python3.11 myenv       # Create venv named "myenv" with Python 3.11
  vstart myenv                    # Activate "myenv"
  vlist                           # List all venvs under $WORKSPACE

EOF
}

# Short aliases
alias vinit='venv-init'
alias vstart='venv-start'
alias vstop='venv-stop'
alias vrestart='venv-restart'
alias vlist='venv-list'
alias vhelp='venv-help'


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
