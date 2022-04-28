#!/bin/sh

alias codei=code-insiders

alias cls='clear'

alias ll='ls -ahlF'
alias ls='ls --color'

alias .='cd .'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias cat="bat --style="changes,header""

# list the PATH separated by new lines
alias lspath='echo $PATH | tr ":" "\n"'

# verbose
alias mkdir='mkdir -v'
alias mv='mv -v'
alias cp='cp -v'
alias rm='rm -v'
alias ln='ln -v'

# time
alias now='date +%s'

LinuxDistro=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')
if [ $LinuxDistro = "Ubuntu" ]; then
        alias suaptup='sudo apt update -y && sudo apt upgrade -y'
fi
