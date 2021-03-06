# git
alias g-repo="git config user.name gh-liu && git config user.email liugh.cs@gmail.com"

alias g="git"

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
alias glogg='git log --graph --decorate --pretty=oneline --abbrev-commit'

# git flow
# https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/git-flow/git-flow.plugin.zsh

# develop -> feature
alias gffs='git flow feature start'
# feature -> develop
alias gfff='git flow feature finish'

# develop -> release
alias gfrs='git flow release start'
# release -> develop
alias gfrf='git flow release finish'

alias gfhs='git flow hotfix start'
alias gfhf='git flow hotfix finish'
