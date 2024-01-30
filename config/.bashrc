# Default editors
export EDITOR='vim'
export GIT_OPEN="$EDITOR"
export VISUAL="$EDITOR"

# local git workspace
if [ -d ~/workspace ]; then
    export WORKSPACE="$HOME/workspace"
    alias ws='cd $WORKSPACE'
fi

# Source aliases
if [ -f ~/.aliases ]; then
    . ~/.aliases
fi

# add kubectl completion
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
fi
