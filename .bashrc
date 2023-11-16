# Default editors
export EDITOR='emacs -nw'
export GIT_OPEN="$EDITOR"
export VISUAL="$EDITOR"

if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
fi

# start emacs daemon if not running
if ! pgrep -f [e]macs; then
    emacs --chdir=$GIT_TREE --daemon
fi

alias emacs='emacsclient -nw'
alias e='emacsclient -nw'
