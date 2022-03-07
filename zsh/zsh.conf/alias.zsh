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

# git
alias g-repo="git config user.name gh-liu && git config user.email liugh.cs@gmail.com"

alias g="git"
alias git-tree='git log --graph --decorate --pretty=oneline --abbrev-commit'
# alias gcn='git commit -v --no-verify'
alias gmn='git merge --no-ff'

alias gco='git checkout'
alias gcb='git checkout -b'

alias gcl='git clone '
alias gst='git status'

alias gb='git branch'
alias ga='git add '

alias ggl='git pull '
alias ggp='git push '

alias gbd='git branch -D '

alias glog='git log --oneline --decorate --graph '
alias gloga='git log --oneline --decorate --graph --all '

# tmux
alias ta='tmux attach -t'
alias ts='tmux new-session -s'
alias tl='tmux list-sessions'

alias {ton,tn}='tmux set mouse on'
alias {tof,tf}='tmux set mouse off'

# tmuxp
alias tpf='tmuxp freeze'
alias tpl='tmuxp load'
alias tpll='tmuxp ls'

# nvim
# alias v='nvim'

# hugo
alias hugos="hugo server -D --bind="0.0.0.0" --baseURL=http://$(hostname -I | awk '{print $1}'):1313"

# time
alias now='date +%s'

# golang
alias fmtf='gofumpt -l -w . && go mod tidy'
alias fmts='gosimports -w . && go mod tidy'

alias gotc='go tool compile -S -N -l'
alias gobs='go build -gcflags -S'

goasm() {
        go build -gcflags=-S 2>&1 $@ | grep -v PCDATA | grep -v FUNCDATA | less
}

LinuxDistro=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')
if [ $LinuxDistro = "Ubuntu" ];then
        alias suaptup='sudo apt update -y && sudo apt upgrade -y'
fi