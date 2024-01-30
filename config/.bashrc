# Default editors
export EDITOR='emacs -nw'
export GIT_OPEN="$EDITOR"
export VISUAL="$EDITOR"

# local git workspace
if [ -d ~/workspace ]; then
    export WORKSPACE="$HOME/workspace"
    alias ws='cd $WORKSPACE'
fi

# start emacs daemon if not running
if ! pgrep -f [e]macs &> /dev/null; then
    emacs --chdir="$WORKSPACE" --daemon
fi

# Source aliases
if [ -f ~/.aliases ]; then
    . ~/.aliases
fi

# add kubectl completion
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
fi
