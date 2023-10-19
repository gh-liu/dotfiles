#!/bin/zsh
if [[ $LinuxDistro == Ubuntu ]]; then
	alias sai='sudo apt install '
	alias sau="sudo apt update -y && sudo apt upgrade -y"
fi

alias .='cd .'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

which exa &>/dev/null && alias ls="exa"
which bat &>/dev/null && alias cat="bat --theme=\"Nord\" --style=\"changes\""

which code-insiders &>/dev/null && alias codei=code-insiders

alias mkdir='mkdir -v'
alias mv='mv -v'
alias cp='cp -v'
alias rm='rm -v'
alias ln='ln -v'

alias cls='clear'

alias now='date +%s'

alias ll='ls -Falh'

alias e=nvim
alias pm=podman
alias lzg=lazygit
alias lzd=lazydocker
alias hugos="hugo server -D --bind="0.0.0.0" --baseURL=http://$HOSTIP:1313"

# podman
# podman pull docker.io/arigaio/atlas:latest
alias atlas1="podman run --rm arigaio/atlas"
