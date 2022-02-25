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
alias gcn='git commit -v --no-verify'
alias gmn='git merge --no-ff'

alias gco='git checkout'
alias gcb='git checkout -b'

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