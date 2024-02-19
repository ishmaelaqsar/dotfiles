# Default editors
export EDITOR='emacs -nw'
export GIT_OPEN="$EDITOR"
export VISUAL="$EDITOR"

# local git workspace
if ! [ -d ~/workspace ]
then
    mkdir ~/workspace
fi
export WORKSPACE="$HOME/workspace"
alias ws='cd $WORKSPACE'

# start emacs daemon if not running
if [ command -v emacs &> /dev/null ] && ! [ pgrep -f [e]macs &> /dev/null ]
then
    emacs --chdir="$WORKSPACE" --daemon
    alias e='emacsclient -nw'
    alias emacs='emacsclient -nw'
fi

# Source aliases
if [ -f ~/.aliases ]
then
    . ~/.aliases
fi

# add kubectl completion
if [ command -v kubectl &> /dev/null ]
then
    source <(kubectl completion bash)
fi
