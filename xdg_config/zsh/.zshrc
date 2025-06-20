# https://unix.stackexchange.com/questions/332791/how-to-permanently-disable-ctrl-s-in-terminal
# setxkbmap -option ctrl:swapcaps

# TODO: zsh zle
# https://zsh.sourceforge.io/Guide/zshguide04.html
# https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#Zle-Widgets
# man zshzle

typeset -U path # keep path unique

export OS=$(echo $(uname -s) | tr '[:upper:]' '[:lower:]')
export ARCH=$(echo $(uname -m) | tr '[:upper:]' '[:lower:]')

# https://zsh.sourceforge.io/Doc/Release/Options.html#History
# HISTORY {{{1
export HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000

setopt INC_APPEND_HISTORY     # Immediately append to history file.
setopt EXTENDED_HISTORY       # Record timestamp in history.
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS       # Dont record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS   # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS      # Do not display a line previously found.
setopt HIST_IGNORE_SPACE      # Dont record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS      # Dont write duplicate entries in the history file.
setopt SHARE_HISTORY          # Share history between all sessions.
unsetopt HIST_VERIFY          # Execute commands using history (e.g.: using !$) immediately
# setopt HIST_VERIFY # !!
# }}}

# https://zsh.sourceforge.io/Doc/Release/Options.html#Changing-Directories
# Changing Directories {{{1
# setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# for index ({1..9}) alias "$index"="cd +${index}"; unset index
alias dirs='dirs -v'
# }}}

# https://zsh.sourceforge.io/Doc/Release/Options.html#Completion-4
# https://zsh.sourceforge.io/Doc/Release/Completion-System.html
# Completion {{{1
# completion https://thevaluable.dev/zsh-completion-guide-examples
if [[ $OS == darwin ]]; then
	# See: https://docs.brew.sh/Shell-Completion
	if type brew &>/dev/null; then
		FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
	fi
fi

# Additional completion
# https://github.com/zsh-users/zsh-completions.git
fpath=($XDG_CONFIG_HOME/zsh/zsh-completions $fpath)

# https://github.com/zsh-users/zsh-completions
fpath=($HOME/.zsh-plugins/zsh-completions/src $fpath)

setopt MENU_COMPLETE # Automatically highlight first element of completion menu

# Should be called before compinit
zmodload zsh/complist
bindkey -M menuselect 'H' vi-backward-char
bindkey -M menuselect 'K' vi-up-line-or-history
bindkey -M menuselect 'J' vi-down-line-or-history
bindkey -M menuselect 'L' vi-forward-char
# bindkey -M menuselect '^xg' clear-screen
# bindkey -M menuselect 'U' undo

zstyle ':completion:*' menu select
zstyle ':completion:*:*:*:*:descriptions' format '%F{blue}-- %D %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'

## case-insensitive (uppercase from lowercase) completion
# zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
## case-insensitive (all) completion
#zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
## case-insensitive,partial-word and then substring completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

_comp_options+=(globdots) # With hidden files
autoload -U +X bashcompinit && bashcompinit
autoload -U +X compinit && compinit
# }}}

# Envs {{{1
export SHELL=$(which zsh)

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# https://github.com/neovim/neovim/wiki/FAQ#colors-arent-displayed-correctly
# export TERM=xterm-256color

if [[ -z "${HOSTIP}" ]]; then
	if [[ $OS == darwin ]]; then
		export HOSTIP=$(ipconfig getifaddr en0)
	fi
	if [[ $OS == linux ]]; then
		export HOSTIP=$(hostname -I | awk '{print $1}')
	fi
fi

# $EDITOR
if command -v nvim &>/dev/null; then
	export EDITOR=nvim
	export MANPAGER='nvim +Man!'
else
	export EDITOR=vim
fi

export PATH=$PATH:$HOME/bin:$HOME/.local/bin

# user directions
export LIU_ENV=$HOME/env
export LIU_DEV=$HOME/dev
export LIU_TOOLS=$HOME/tools
# }}}

# Plugins {{{1
function git_clone_or_update() {
	git clone "$1" "$2" 2>/dev/null && echo 'Clone status: Success' || (
		cd "$2"
		git pull
	)
}
function update_zsh_plugins() {
	mkdir -p $HOME/.zsh-plugins
	git_clone_or_update https://github.com/zsh-users/zsh-autosuggestions $HOME/.zsh-plugins/zsh-autosuggestions
	git_clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting $HOME/.zsh-plugins/zsh-syntax-highlighting
	git_clone_or_update https://github.com/zsh-users/zsh-completions.git $HOME/.zsh-plugins/zsh-completions
	# git_clone_or_update https://github.com/marlonrichert/zsh-autocomplete.git $HOME/.zsh-plugins/zsh-autocomplete

	git_clone_or_update https://github.com/jeffreytse/zsh-vi-mode $HOME/.zsh-plugins/zsh-vi-mode

	# git_clone_or_update https://github.com/hutusi/git-paging.git $HOME/.zsh-plugins/git-paging
	# ln -svf $HOME/.zsh-plugins/git-paging/git-* $HOME/.local/bin
}

# https://github.com/zsh-users/zsh-autosuggestions
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=12
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source $HOME/.zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^l' forward-word

# https://github.com/zsh-users/zsh-syntax-highlighting
source $HOME/.zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# https://github.com/jeffreytse/zsh-vi-mode
function zvm_config() {
	ZVM_VI_INSERT_ESCAPE_BINDKEY=jk

	ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
	ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
	# ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK

	# https://github.com/jeffreytse/zsh-vi-mode?tab=readme-ov-file#custom-widgets-and-keybindings
	# zvm_bindkey <keymap> <keys> <widget>
	# NOTE: Run `cat` then press keys to see the codes your shortcut send
	zvm_bindkey viins '^[f' vi-forward-word
	zvm_bindkey viins '^[b' vi-backward-word
}
# disable in nvim terminal buffer
if [[ -z "${NVIM}" ]]; then
	source $HOME/.zsh-plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh
fi
# zvm_bindkey vicmd '^e' zvm_vi_edit_command_line
# }}}

# Langs {{{1
# Golang {{{2
export GO111MODULE=on
export GOPATH=$LIU_ENV/golang/gopath
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN
export PATH=$PATH:$LIU_ENV/golang/go/bin

alias gotc='go tool compile -S -N -l'
alias gobs='go build -gcflags -S'

function goasm() {
	go build -gcflags=-S $@ 2>&1 | grep -v PCDATA | grep -v FUNCDATA | less
}

function gocover() {
	local t=$(mktemp -t)
	go test $COVERFLAGS -coverprofile=$t $@ && go tool cover -func=$t && unlink $t
}

function gotrace() {
	go tool trace -http=$HOSTIP:7777 $@
}

function gotrace2() {
	local t=$(mktemp -t)
	local ip=$1
	local port=$2
	wget "http://$ip:$port/debug/pprof/trace" --output-document $t
	go tool trace -http=$HOSTIP:7777 $t
	unlink $t
}

function gopprof() {
	go tool pprof -http=$HOSTIP:7788 -no_browser $@
}

function gopprof2() {
	local ip="${1:-$HOSTIP}"
	local port="${2:-6060}"
	local typ="${3:-profile}"
	go tool pprof -http=$HOSTIP:7788 -no_browser "http://$ip:$port/debug/pprof/$typ"
}

function goprotoc() {
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative $@
}
# }}}

# Rust {{{2
export RUSTUP_HOME=$LIU_ENV/rust/rustup

export CARGO_HOME=$LIU_ENV/rust/cargo
export CARGO_BIN=$LIU_ENV/rust/cargo/bin
export PATH=$PATH:$CARGO_BIN
# }}}

# Nodejs {{{2
# export PATH=$PATH:$LIU_ENV/nodejs/node/bin

# curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# }}}

# zig:zvm {{{
# zvm i master
# zvm i --zls master
export PATH=$PATH:$HOME/.zvm/bin
# }}}

# python {{{
# export PYTHONBIN=$LIU_ENV/python/bin
# export PATH=$PATH:$PYTHONBIN

function _venv() {
	local venv_path=${1:=".venv"}
	if [ -d "$venv_path" ]; then
		source "$venv_path/bin/activate"
	else
		echo "Virtual environment not found: $venv_path"
		return 1
	fi
}
alias venva=_venv

# curl -LsSf https://astral.sh/uv/install.sh | sh
if [[ -f "$(which uv)" ]]; then
	eval "$(uv generate-shell-completion zsh)"
	eval "$(uvx --generate-shell-completion zsh)"
fi
# export UV_PYTHON_INSTALL_DIR="$HOME/.uvpython"
# export UV_TOOL_BIN_DIR=$LIU_ENV/uvpython/bin
# export PATH=$PATH:$UV_TOOL_BIN_DIR
# }}}
# }}}

# Tools {{{1
## brew
if [[ $OS == darwin ]]; then
	export PATH=$PATH:/opt/homebrew/bin
	export HOMEBREW_BUNDLE_FILE=$XDG_CONFIG_HOME/Brewfile
fi

## starship
# curl -sS https://starship.rs/install.sh | sh
export STARSHIP_CONFIG=$ZDOTDIR/starship/starship.toml
[ -f "$(which starship)" ] && eval "$(starship init zsh)"

## direnv
# curl -sfL https://direnv.net/install.sh | bash
[ -f "$(which direnv)" ] && eval "$(direnv hook zsh)"

## fzf
# NOTE: https://github.com/junegunn/fzf?tab=readme-ov-file#search-syntax
#
# NOTE: https://github.com/junegunn/fzf?tab=readme-ov-file#key-bindings-for-command-line
#
export FZF_DEFAULT_OPTS='--height 50% --border --reverse'
### https://github.com/junegunn/fzf/blob/master/ADVANCED.md#color-themes
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color=fg:#e5e9f0,bg:#2E3440,hl:#81a1c1
--color=fg+:#e5e9f0,bg+:#2E3440,hl+:#81a1c1
--color=info:#eacb8a,prompt:#bf6069,pointer:#b48dac
--color=marker:#a3be8b,spinner:#b48dac,header:#a3be8b'
[ -f "$(which fzf)" ] && source <(fzf --zsh)

## zoxide
[ -f "$(which zoxide)" ] && eval "$(zoxide init zsh)" # must be added after compinit is called.

if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
	source $GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration
fi

## go tool present: https://pkg.go.dev/golang.org/x/tools/present
_gopresent() {
	present -http "$(hostname -I | awk '{print $1}'):3999"
}
alias gopresent=_gopresent
# }}}

# Git {{{1
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
alias gc='git commit '

alias ggl='git pull '
alias ggp='git push '

alias gbd='git branch -D '
alias gbD='git push origin -d'

alias glog='git log --oneline --decorate --graph --pretty=format:"%C(auto)%h%d (%ci) %cn %s"'
alias gloga='glog --all '

alias gccs='git config credential.helper store'

# empty commit: https://stackoverflow.com/questions/40883798/how-to-get-git-diff-of-the-first-commit#comment68984343%5F40884093
# export EMPTY_GIT_TREE=$(printf '' | git hash-object -t tree --stdin)
export EMPTY_GIT_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

# https://lobste.rs/s/2iogwz/git_programmatic_staging
# go install rsc.io/grepdiff@latest
# https://en.wikipedia.org/wiki/Process_substitution
function gam {
	grepdiff $1 <(git diff) | git apply --cached
}

function gdir() {
	cd $(git rev-parse --git-dir)
	cd ..
}

HASH="%C(always,yellow)%h%C(always,reset)"
RELATIVE_TIME="%C(always,green)%ar%C(always,reset)"
AUTHOR="%C(always,bold blue)%an%C(always,reset)"
REFS="%C(always,red)%d%C(always,reset)"
SUBJECT="%s"

pretty_git_log() {
	FORMAT="$HASH $RELATIVE_TIME{$AUTHOR{$REFS $SUBJECT"
	git log --graph --pretty="tformat:$FORMAT" $* |
		column -t -s '{' |
		less -XRS --quit-if-one-screen
}

# [f]uzzy check[o]ut
fo() {
	git branch --no-color --sort=-committerdate --format='%(refname:short)' | fzf --header 'git checkout' | xargs git checkout
}
# [f]uzzy [p]ull request check[o]ut
fpo() {
	# gh pr list --author "@me" | fzf --header 'checkout PR' | awk '{print $(NF-5)}' | xargs git checkout
	gh pr list | fzf --header 'checkout PR' | awk '{print $(1)}' | xargs gh pr checkout
}

# }}}

# Tmux {{{1
ftmux() {
	if [[ ! -n $TMUX ]]; then
		# get the IDs
		ID="$(tmux list-sessions)"
		if [[ -z "$ID" ]]; then
			session=$(basename "$PWD")
			tmux new-session -s $session
		else
			create_new_session="Create New Session"
			ID="$ID\n${create_new_session}:"
			ID="$(echo $ID | fzf | cut -d: -f1)"
			if [[ "$ID" = "${create_new_session}" ]]; then
				printf "%s" "Enter session name: "
				read session
				if [ -z "$session" ]; then
					session=$(basename $(pwd))
				fi
				tmux new-session -s $session
			elif [[ -n "$ID" ]]; then
				printf '\033]777;tabbedx;set_tab_name;%s\007' "$ID"
				tmux attach-session -t "$ID"
			else
				: # Start terminal normally
			fi
		fi
	fi
}

alias f='ftmux'

ftmuxp() {
	sessions="$(tmuxp ls)"
	session=$(echo "$sessions" | eval "fzf --header \"tmux sessions\"")
	[[ -z "$session" ]] && exit
	tmuxp load --yes $session >/dev/null
}
# }}}

# aliases & functions {{{
alias .='cd .'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias mkdir='mkdir -v'
alias mv='mv -v'
alias cp='cp -v'
alias rm='rm -v'
alias ln='ln -v'

alias ll='ls -F -a -l -h'

alias cls='clear'

alias grep="grep --color"

alias now='date +%s'

alias e=nvim

which eza &>/dev/null && alias ls="eza"
which bat &>/dev/null && alias cat="bat --theme=\"Nord\" --style=\"changes\""
which fd &>/dev/null && alias find="fd"

function extract {
	if [ -z "$1" ]; then
		echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
	else
		if [ -f $1 ]; then
			case $1 in
			*.tar.bz2) tar xvjf $1 ;;
			*.tar.gz) tar xvzf $1 ;;
			*.tar.xz) tar xvJf $1 ;;
			*.lzma) unlzma $1 ;;
			*.bz2) bunzip2 $1 ;;
			*.rar) unrar x -ad $1 ;;
			*.gz) gunzip $1 ;;
			*.tar) tar xvf $1 ;;
			*.tbz2) tar xvjf $1 ;;
			*.tgz) tar xvzf $1 ;;
			*.zip) unzip $1 ;;
			*.Z) uncompress $1 ;;
			*.7z) 7z x $1 ;;
			*.xz) unxz $1 ;;
			*.exe) cabextract $1 ;;
			*) echo "extract: '$1' - unknown archive method" ;;
			esac
		else
			echo "$1 - file does not exist"
		fi
	fi
}
alias extr='extract '
# }}}

# User Configuration
[ -f $ZDOTDIR/zsh-conf/custom.zsh ] && source $ZDOTDIR/zsh-conf/custom.zsh

# NOTE: `man zshmisc`, see `EXPANSION`
# %n     $USERNAME.
# %M     The full machine hostname.
# %~     Current working directory.
#
# https://www.x.org/docs/xterm/ctlseqs.pdf
# \e]2;balabala  -> Change Window Title to balabala
# 
# https://zsh.sourceforge.io/Doc/Release/Functions.html
# precmd: Executed before each prompt.
# chpwd: Executed whenever the current working directory is changed.
chpwd() {print -Pn "\e]2;%n@%M: %~\a"}

## vim: foldmethod=marker foldlevel=0
