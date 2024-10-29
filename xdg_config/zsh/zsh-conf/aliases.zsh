#!/bin/zsh
if [[ $LinuxDistro == Ubuntu ]]; then
	alias sai='sudo apt install '
	alias sau="sudo apt update -y && sudo apt upgrade -y"
fi

alias .='cd .'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

which eza &>/dev/null && alias ls="eza"
which bat &>/dev/null && alias cat="bat --theme=\"Nord\" --style=\"changes\""
which fd &>/dev/null && alias find="fd"

which code-insiders &>/dev/null && alias codei=code-insiders

alias mkdir='mkdir -v'
alias mv='mv -v'
alias cp='cp -v'
alias rm='rm -v'
alias ln='ln -v'

alias cls='clear'

alias now='date +%s'

alias ll='ls -F -a -l -h'

alias e=nvim
alias pm=podman
alias lzg=lazygit
alias lzd=lazydocker
alias hugos="hugo server -D --bind="0.0.0.0" --baseURL=http://$HOSTIP:1313"
if [[ $OS == darwin ]]; then
	alias hugoso="open http://$HOSTIP:1313"
fi
hugon() {
	hugo new content content/posts/$1/index.md
}

alias grep="grep --color"

alias sshagent='eval $(ssh-agent -s) && ssh-add'

# podman
# podman pull docker.io/arigaio/atlas:latest
alias atlas1="podman run --rm arigaio/atlas"
atlas1schemadiff() {
	atlas1 schema diff --to $1 --from $2
}
