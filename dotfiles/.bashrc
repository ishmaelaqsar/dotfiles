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

# start emacs daemon if not running
if [ command -v emacs &> /dev/null ] && ! [ pgrep -f [e]macs &> /dev/null ]
then
    emacs --chdir="$WORKSPACE" --daemon
    export EDITOR='emacs -nw'
    alias e='emacsclient -nw'
    alias emacs='emacsclient -nw'
else
    export EDITOR='nano'
fi

export GIT_OPEN="$EDITOR"
export VISUAL="$EDITOR"

export LC_CTYPE=en_GB.UTF-8
export LC_ALL=en_GB.UTF-8

# setup cpan local::lib
if [ command -v cpanm &> /dev/null ]
then
    cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
fi

# run these commands only when running in a container
if [[ -v CONTAINER_ID ]]
then
    echo "running in a container"
fi

# add kubectl completion
if [ command -v kubectl &> /dev/null ]
then
    source <(kubectl completion bash)
fi
