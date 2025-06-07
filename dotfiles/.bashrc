PROMPT_COMMAND='
PS1_CMD1=$(git branch --show-current 2>/dev/null);
PS1_JOBS=$(jobs -p | wc -l);
PS1_JOBS=${PS1_JOBS// /}; # Trim spaces
[[ $PS1_CMD1 ]] && PS1_BRANCH="[$PS1_CMD1]" || PS1_BRANCH="";
[[ $PS1_JOBS -gt 0 ]] && PS1_JNUM="[$PS1_JOBS]" || PS1_JNUM="";
PS1=" \w $PS1_JNUM$PS1_BRANCH \$ "
'

# run these commands only when running in a container
if [[ -v CONTAINER_ID ]]
then
    export LC_ALL=en_US.utf8
fi

# Source global definitions
if [ -f /etc/bashrc ];
then
    . /etc/bashrc
fi

# Source aliases
if [ -f ~/.aliases ]
then
    . ~/.aliases
fi

# local git workspace
if ! [ -d ~/workspace ]
then
    mkdir ~/workspace
fi
export WORKSPACE="$HOME/workspace"
alias ws='cd $WORKSPACE'

# check if emacs is installed
#if command -v emacs >/dev/null 2>&1
#then
#    export EDITOR='emacs -nw'
#    # Check if a daemon is already running
#    if ! pgrep -a emacs | grep daemon >/dev/null 2>&1
#    then
#        emacs --daemon --chdir="$WORKSPACE"
#    fi
#    alias e='emacsclient -nw'
#    alias emacs='emacsclient -nw'
#else
#    export EDITOR='nano'
#fi

export EDITOR='vi'
export GIT_OPEN="$EDITOR"
export VISUAL="$EDITOR"

# setup cpan local::lib
if command -v cpanm >/dev/null 2>&1
then
    if cpanm --local-lib=~/perl5 local::lib >/dev/null 2>&1
    then
        eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
    fi
fi

# add kubectl completion
if command -v kubectl >/dev/null 2>&1
then
    source <(kubectl completion bash)
fi

# podman completion
if command -v podman >/dev/null 2>&1
then
    source <(podman completion bash)
fi

# User specific aliases and functions
if [ -d ~/.bashrc.d ]
then
    for rc in ~/.bashrc.d/*; do
        [ -r "$rc" ] && . "$rc"
    done
fi
unset rc

#[ -n "$EAT_SHELL_INTEGRATION_DIR" ] && \
#    source "$EAT_SHELL_INTEGRATION_DIR/bash"
