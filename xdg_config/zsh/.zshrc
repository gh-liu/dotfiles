# time  zsh -i -c exit
# NOTE: uncomment below line for profile
# zmodload zsh/zprof

typeset -U path # keep path unique

# 1. env vars{{{
if [[ -z "${OS}" ]]; then
	export OS=$(echo $(uname -s) | tr '[:upper:]' '[:lower:]')
fi
if [[ -z "${ARCH}" ]]; then
	export ARCH=$(echo $(uname -m) | tr '[:upper:]' '[:lower:]')
fi
if [[ -z "${HOSTIP}" ]]; then
	if [[ $OS == darwin ]]; then
		export HOSTIP=$(ipconfig getifaddr en0)
	fi
	if [[ $OS == linux ]]; then
		export HOSTIP=$(hostname -I | awk '{print $1}')
	fi
fi
export LIU_ENV=$HOME/env
export LIU_DEV=$HOME/dev
export LIU_TOOLS=$HOME/tools
## sys
export SHELL=$(which zsh)
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR=nvim
export MANPAGER='nvim +Man!'
# https://github.com/neovim/neovim/wiki/FAQ#colors-arent-displayed-correctly
# export TERM=xterm-256color
export PATH=$PATH:$HOME/bin:$HOME/.local/bin
# }}}

# 2. git{{{
alias g-repo="git config user.name gh-liu && git config user.email liugh.cs@gmail.com"
alias g="git"
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcl='git clone '
alias ggl='git pull '
alias ggp='git push '
alias gst='git status'
alias gbd='git branch -D '
alias gbD='git push origin -d'
alias glog='git log --oneline --decorate --graph --pretty=format:"%C(auto)%h%d (%ci) %cn %s"'
alias gccs='git config credential.helper store'
alias gwta='git worktree add'
alias gwtr='git worktree remove'
alias gwtl='git worktree list'
## pretty git log
glogp() {
	HASH="%C(always,yellow)%h%C(always,reset)"
	RELATIVE_TIME="%C(always,green)%ar%C(always,reset)"
	AUTHOR="%C(always,bold blue)%an%C(always,reset)"
	REFS="%C(always,red)%d%C(always,reset)"
	SUBJECT="%s"
	FORMAT="$HASH $RELATIVE_TIME{$AUTHOR{$REFS $SUBJECT"
	git log --graph --pretty="tformat:$FORMAT" $* |
		column -t -s '{' |
		less -XRS --quit-if-one-screen
}
gproxy() {
	# ~/.ssh/config
	#
	# Host github.com
	#    Hostname ssh.github.com
	#    Port 443
	#    User git
	git config http.proxy "${http_proxy:-http://127.0.0.1:1080}"
	git config https.proxy "${https_proxy:-http://127.0.0.1:1080}"
}
gproxyunset() {
	git config --global --unset http.proxy
	git config --global --unset https.proxy
}
## [f]uzzy check[o]ut
fo() {
	git branch --no-color --sort=-committerdate --format='%(refname:short)' | fzf --header 'git checkout' | xargs git checkout
}
## [f]uzzy [r]emote check[o]ut
fro() {
	git branch --no-color --sort=-committerdate --format='%(refname:short)' --remote | fzf --header 'git checkout remote' | xargs git checkout -t
}
## [f]uzzy [p]ull request check[o]ut
fpo() {
	# gh pr list --author "@me" | fzf --header 'checkout PR' | awk '{print $(NF-5)}' | xargs git checkout
	gh pr list --limit 1000 | fzf --header 'checkout PR' | awk '{print $(1)}' | xargs gh pr checkout
}
## [f]uzzy gh [r]epo [c]lone
frc() {
	gh repo list --limit 1000 $1 | fzf --header 'clone repo' | awk '{print $(1)}' | xargs gh repo clone
}
# }}}

# 3. tmux{{{
alias f='ftmux'
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
alias fp='ftmuxp'
ftmuxp() {
	sessions="$(tmuxp ls)"
	session=$(echo "$sessions" | eval "fzf --header \"tmux sessions\"")
	[[ -z "$session" ]] && exit
	tmuxp load --yes $session >/dev/null
}
# }}}

# 4. alias, function{{{
alias .='cd .'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias mkdir='mkdir -v'
alias mv='mv -v'
alias cp='cp -v'
alias rm='rm -v'
alias ln='ln -v'
alias cls='clear'
alias now='date +%s'
alias grep="grep --color"
alias ll='ls -F -a -l -h'
## function
alias cdf='cdfiledir '
function cdfiledir {
	[ $# -eq 0 ] && {
		echo "Usage: cdf <file-or-dir>" >&2
		return 1
	}
	cd "$(dirname -- "$1")"
}

alias extr='extract '
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
skilla() {
	case $# in
	1) add-skill "$1" --list ;;
	2)
		repo=$1
		skills=$2
		set -- "$repo" # reset positional args
		IFS=','
		for s in $skills; do
			set -- "$@" --skill "$s"
		done
		add-skill "$@"
		;;
	*)
		echo "Usage: skilla <repo> | skilla <repo> skill1,skill2,..." >&2
		return 1
		;;
	esac
}
# }}}

# 5. plugins{{{
declare -a USERPLUGINS
export USERPLUGINSHOME=$HOME/.zsh-plugins
function update_zsh_plugins() {
	mkdir -p $USERPLUGINSHOME
	for plugin in "${USERPLUGINS[@]}"; do
		print $plugin
		name=${plugin##*/}
		pluginpath=$HOME/.zsh-plugins/$name
		# print $pluginpath
		git clone "$plugin" "$pluginpath" 2>/dev/null && echo 'Clone status: Success' || (
			cd "$pluginpath"
			git pull
		)
	done
}
# }}}
# 6. plugin: zsh-autosuggestions{{{
## https://github.com/zsh-users/zsh-autosuggestions
USERPLUGINS+=(https://github.com/zsh-users/zsh-autosuggestions)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=12
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source $USERPLUGINSHOME/zsh-autosuggestions/zsh-autosuggestions.zsh
# bindkey '^l' forward-word
# }}}
# 6. plugin: zsh-syntax-highlighting{{{
## https://github.com/zsh-users/zsh-syntax-highlighting
USERPLUGINS+=(https://github.com/zsh-users/zsh-syntax-highlighting)
source $USERPLUGINSHOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# }}}
# 6. plugin: zsh-vi-mode{{{
## https://github.com/jeffreytse/zsh-vi-mode
USERPLUGINS+=(https://github.com/jeffreytse/zsh-vi-mode)
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
## disable in nvim terminal buffer
if [[ -z "${NVIM}" ]]; then
	source $HOME/.zsh-plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh
fi
# }}}

# 8. changing directories{{{
## https://zsh.sourceforge.io/Doc/Release/Options.html#Changing-Directories
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
# }}}
# 8. history{{{
## https://zsh.sourceforge.io/Doc/Release/Options.html#History
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
# 8. zle{{{
## https://zsh.sourceforge.io/Guide/zshguide04.html
## https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#Zle-Widgets
## man zshzle
# }}}
# 8. completion{{{
update_zsh_completions() {
	mkdir -p "$XDG_CONFIG_HOME"/zsh/zsh-completions

	[ -f "$(which atuin)" ] && atuin gen-completions --shell zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_atuin
	[ -f "$(which bun)" ] && SHELL=zsh bun completions >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_bun
	[ -f "$(which docker)" ] && docker completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_docker
	[ -f "$(which gh)" ] && gh completion -s zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_gh
	[ -f "$(which git-absorb)" ] && git-absorb --gen-completions zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_git-absorb
	[ -f "$(which helm)" ] && helm completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_helm
	[ -f "$(which just)" ] && just --completions=zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_just
	[ -f "$(which kubectl)" ] && kubectl completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_kubectl
	[ -f "$(which minikube)" ] && minikube completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_minikube
	[ -f "$(which podman)" ] && podman completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_podman
	[ -f "$(which rustc)" ] && cp "$(rustc --print sysroot)"/share/zsh/site-functions/_cargo "$XDG_CONFIG_HOME"/zsh/zsh-completions/_cargo
	[ -f "$(which rustup)" ] && rustup completions zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_rustup
	[ -f "$(which starship)" ] && starship completions zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_starship

	[ -f "$(which ollama)" ] && curl https://gist.githubusercontent.com/obeone/9313811fd61a7cbb843e0001a4434c58/raw/_ollama.zsh \
		>"$XDG_CONFIG_HOME"/zsh/zsh-completions/_ollama

	compinit
}

## https://zsh.sourceforge.io/Doc/Release/Options.html#Completion-4
## https://zsh.sourceforge.io/Doc/Release/Completion-System.html
## man zshcompsys
## additional src: https://github.com/zsh-users/zsh-completions
USERPLUGINS+=(https://github.com/zsh-users/zsh-completions.git)
fpath=($HOME/.zsh-plugins/zsh-completions/src $fpath)
fpath=($XDG_CONFIG_HOME/zsh/zsh-completions $fpath)
if [[ $OS == darwin ]]; then
	# See: https://docs.brew.sh/Shell-Completion
	if type brew &>/dev/null; then
		FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
	fi
fi

## automatically highlight first element of completion menu
setopt MENU_COMPLETE
## Should be called before compinit
zmodload zsh/complist
## navigation
bindkey -M menuselect 'H' vi-backward-char
bindkey -M menuselect 'K' vi-up-line-or-history
bindkey -M menuselect 'J' vi-down-line-or-history
bindkey -M menuselect 'L' vi-forward-char
## Tab and ShiftTab cycle completions
bindkey '^I' menu-complete
bindkey "$terminfo[kcbt]" reverse-menu-complete
## NOTE: zstyle <pattern> <style> <values>
### 1. The <pattern> act as a namespace
### :completion:<function>:<completer>:<command>:<argument>:<tag>
### Think of a <tag> as a type of match. `man zshcompsys` - Search for 'Standard Tags'
### 2. The <style>. `man zshcompsys` - Search for 'Standard Styles'
### NOTE: the sequence %F %f in the style’s value to use a foreground color
### the sequence %K %k in the style’s value to use a background color
### %B %b for Bold, %U %u for Underline
### %d for description or context specific?
zstyle ':completion:*' menu select                                  # menu-driven completion
zstyle ':completion:*' group-name ''                                # group the matches under their descriptions
zstyle ':completion:*' file-list all                                # files and folder matched with more details
zstyle ':completion:*' completer _extensions _complete _approximate # `man zshcompsys` - Search for 'Control Functions'
# zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'        # try a case-insensitive completion if nothing matches
zstyle ':completion:*:*:*:*:descriptions' format '%F{blue}-- %d --%f'
zstyle ':completion:*:*:*:*:warnings' format '%F{red}-- no matches found --%f'
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:*:*:*:messages' format ' %F{purple} -- %d --%f' # ? what's messages?

zstyle ':completion:*:(ssh|scp):*:hosts' hosts
zstyle ':completion:*:ssh:argument-1:' tag-order hosts users
zstyle ':completion:*:scp:argument-rest:' tag-order hosts files users

zstyle ':completion:*:*:kill:*' command 'ps -u $USER -o pid,user,%cpu,tty,cputime,cmd'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;32'

# autoload
# +X  load the definition without executing
# compinit
# https://github.com/zsh-users/zsh/blob/f5abf18f2c0cb1ad5fae67d12e218148b9541d66/Completion/compinit#L67
# -C  bypasses both the check for rebuilding the dump file and the usual call to compaudit
autoload -U +X bashcompinit && bashcompinit
# autoload -U +X compinit && compinit -u
autoload -U +X compinit
if [[ -z "${USERCOMPINITDONE}" ]]; then
	export USERCOMPINITDONE=1
	compinit
else
	compinit -C
fi

[ -f "$(which terraform)" ] && complete -o nospace -C $(which terraform) terraform
# }}}
# 8. functions{{{
## https://github.com/zsh-users/zsh/blob/master/Functions/Misc/zmv
autoload -Uz zmv
# }}}

# 7. lang: go{{{
export GO111MODULE=on
export GOPATH=$LIU_ENV/golang/gopath
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN
export PATH=$PATH:$LIU_ENV/golang/go/bin
## pprof
function gopprof() {
	go tool pprof -http=$HOSTIP:7788 -no_browser $@
}
function gopprof2() {
	local ip="${1:-$HOSTIP}"
	local port="${2:-6060}"
	local typ="${3:-profile}"
	go tool pprof -http=$HOSTIP:7788 -no_browser "http://$ip:$port/debug/pprof/$typ"
}
## trace
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
## asm, compile
alias gotc='go tool compile -S -N -l'
alias gobs='go build -gcflags -S'
function goasm() {
	go build -gcflags=-S $@ 2>&1 | grep -v PCDATA | grep -v FUNCDATA | less
}
## test cover
function gocover() {
	local t=$(mktemp -t)
	go test $COVERFLAGS -coverprofile=$t $@ && go tool cover -func=$t && unlink $t
}
## present: https://pkg.go.dev/golang.org/x/tools/present
alias gopresent=_gopresent
_gopresent() {
	present -http "$(hostname -I | awk '{print $1}'):3999"
}
# }}}
# 7. lang: python{{{
## uv: curl -LsSf https://astral.sh/uv/install.sh | sh
export UV_TOOL_BIN_DIR=$LIU_ENV/python/bin
export PATH=$PATH:$UV_TOOL_BIN_DIR
if [[ -f "$(which uv)" ]]; then
	eval "$(uv generate-shell-completion zsh)"
	eval "$(uvx --generate-shell-completion zsh)"
fi
export UV_PYTHON_INSTALL_DIR=$LIU_ENV/python
## venv activate
alias va=_venv
function _venv() {
	local venv_path=${1:=".venv"}
	if [ -d "$venv_path" ]; then
		source "$venv_path/bin/activate"
	else
		echo "Virtual environment not found: $venv_path"
		return 1
	fi
}
# }}}
# 7. lang: rust{{{
## rustup: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
export RUSTUP_HOME=$LIU_ENV/rust/rustup
## cargo
export CARGO_HOME=$LIU_ENV/rust/cargo
export CARGO_BIN=$CARGO_HOME/bin
export PATH=$PATH:$CARGO_BIN
# }}}
# 7. lang: zig{{{
export PATH=$PATH:$LIU_ENV/zig/zig
# }}}
# 7. lang: js{{{
## bun: curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$LIU_ENV/nodejs/bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# bun completions
# https://github.com/oven-sh/bun/issues/11179#issuecomment-2151457758
# }}}

# 9. tools: AS many tools install by lang, so let it at BOTTOM{{{
## brew: all the bins installed by brew should put after
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
export FZF_COMPLETION_TRIGGER=',,'
# NOTE: https://github.com/junegunn/fzf?tab=readme-ov-file#search-syntax
# NOTE: https://github.com/junegunn/fzf?tab=readme-ov-file#key-bindings-for-command-line
export FZF_DEFAULT_OPTS='--height 50% --border --reverse'
### https://github.com/junegunn/fzf/blob/master/ADVANCED.md#color-themes
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color=fg:#e5e9f0,bg:#2E3440,hl:#81a1c1
--color=fg+:#e5e9f0,bg+:#2E3440,hl+:#81a1c1
--color=info:#eacb8a,prompt:#bf6069,pointer:#b48dac
--color=marker:#a3be8b,spinner:#b48dac,header:#a3be8b'
if [ -f "$(which fd)" ]; then
	_fzf_compgen_path() {
		fd --color never --hidden --follow --exclude ".git" . "$1"
	}
	_fzf_compgen_dir() {
		fd --type d --color never --hidden --follow --exclude ".git" . "$1"
	}
fi
[ -f "$(which fzf)" ] && source <(fzf --zsh)
## zoxide
[ -f "$(which zoxide)" ] && eval "$(zoxide init zsh)" # must be added after compinit is called.

which nvim &>/dev/null && alias e=nvim
which fd &>/dev/null && alias find="fd"
which eza &>/dev/null && alias ls="eza"
which bat &>/dev/null && alias cat="bat --theme=\"Nord\" --style=\"changes\""
# }}}

# 999. misc{{{
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
precmd() {
	_set_title "$@"
}
## from: https://github.com/tpope/dotfiles/blob/30b0609c6bdc38eb607530d6a1b603dbfdc8a8ef/.zshrc#L52
_set_title() {
	case "$1" in
	*install*)
		hash -r
		;;
	esac
	print -Pn '\e]1;%l@%m${1+*}\a'
	print -Pn '\e]2;%n@%m:%~'
	if [ -n "$1" ]; then
		print -Pnr ' (%24>..>$1%>>)' | tr '\0-\037' '?'
	fi
	print -Pn " [%l]\a"
}

export PATH=$PATH:$XDG_CONFIG_HOME/bin
[ -f $ZDOTDIR/zsh-conf/custom.zsh ] && source $ZDOTDIR/zsh-conf/custom.zsh
# }}}

# 9999. LLM {{{
# #claude
# export ANTHROPIC_API_KEY=""
# export ANTHROPIC_BASE_URL=""
# export ANTHROPIC_MODEL=
# export ANTHROPIC_SMALL_FAST_MODEL=
# #openai
# export OPENAI_API_KEY=""
# export OPENAI_BASE_URL=""
# #deepseek
# export DEEPSEEK_API_KEY=""
# #gemini
# export GOOGLE_GEMINI_BASE_URL=""
# export GEMINI_API_KEY=""
# }}}

# NOTE: uncomment below line for profile
# zprof

## vim: foldmethod=marker foldlevel=0
