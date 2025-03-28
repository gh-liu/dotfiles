#!/bin/zsh
# aliases{{{1
# git{{{2
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
alias gbD='git push origin -d'

alias glog='git log --oneline --decorate --graph --pretty=format:"%C(auto)%h%d (%ci) %cn %s"'
alias gloga='glog --all '

alias gstl='git stash list '
alias gsta='git stash save '
alias gstp='git stash pop '
alias gstaa='git stash apply '

alias gccs='git config credential.helper store'
# }}}

# git flow {{{2
# https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/git-flow/git-flow.plugin.zsh
alias gf='git flow'

# develop -> feature
alias gffs='git flow feature start'
# feature -> develop
alias gfff='git flow feature finish'

# develop -> release
alias gfrs='git flow release start'
# release -> develop
alias gfrf='git flow release finish'

# develop -> bugfix
alias gfbs='git flow bugfix start'
#  bugfix-> develop
alias gfbf='git flow bugfix finish'

# main -> hotfix
alias gfhs='git flow hotfix start'
#  hotfix-> main
alias gfhf='git flow hotfix finish'
# }}}
# }}}

# empty commit: https://stackoverflow.com/questions/40883798/how-to-get-git-diff-of-the-first-commit#comment68984343%5F40884093
# export EMPTY_GIT_TREE=$(printf '' | git hash-object -t tree --stdin)
export EMPTY_GIT_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

# https://lobste.rs/s/2iogwz/git_programmatic_staging
# go install rsc.io/grepdiff@latest
# https://en.wikipedia.org/wiki/Process_substitution
function gam {
	grepdiff $1 <(git diff) | git apply --cached
}

HASH="%C(always,yellow)%h%C(always,reset)"
RELATIVE_TIME="%C(always,green)%ar%C(always,reset)"
AUTHOR="%C(always,bold blue)%an%C(always,reset)"
REFS="%C(always,red)%d%C(always,reset)"
SUBJECT="%s"

FORMAT="$HASH $RELATIVE_TIME{$AUTHOR{$REFS $SUBJECT"

pretty_git_log() {
	git log --graph --pretty="tformat:$FORMAT" $* |
		column -t -s '{' |
		less -XRS --quit-if-one-screen
}

# [f]uzzy check[o]ut
fo() {
	git branch --no-color --sort=-committerdate --format='%(refname:short)' | fzf --header 'git checkout' | xargs git checkout
}
# [p]ull request check[o]ut
po() {
	# gh pr list --author "@me" | fzf --header 'checkout PR' | awk '{print $(NF-5)}' | xargs git checkout
	gh pr list | fzf --header 'checkout PR' | awk '{print $(NF-5)}' | xargs git checkout
}

# vim: foldmethod=marker
