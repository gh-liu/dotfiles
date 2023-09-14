# https://unix.stackexchange.com/questions/332791/how-to-permanently-disable-ctrl-s-in-terminal
# setxkbmap -option ctrl:swapcaps

# {{{1 Options
# https://zsh.sourceforge.io/Doc/Release/Options.html
# Append history to the history file (no overwriting)
setopt appendhistory
# Remove command lines from the history list when the first character on the
# line is a space, or when one of the expanded aliases contains a leading space
setopt histignorespace
# }}}

# {{{1 Envs
export SHELL=$(which zsh)

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

export HISTFILE=$HOME/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000

# https://github.com/neovim/neovim/wiki/FAQ#colors-arent-displayed-correctly
export TERM=xterm-256color

export OS=$(echo $(uname) | tr '[:upper:]' '[:lower:]')
if [[ $OS == darwin ]]; then
    export HOSTIP=$(ipconfig getifaddr en0)
fi

if [[ $OS == linux ]]; then
    export HOSTIP=$(hostname -I | awk '{print $1}')
    export LinuxDistro=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')
fi

# $EDITOR
if command -v nvim &>/dev/null; then
    export EDITOR=nvim
    export MANPAGER='nvim +Man!'
else
    export EDITOR=vim
fi

# user directions
export LIU_ENV=$HOME/env
export LIU_DEV=$HOME/dev
export LIU_TOOLS=$HOME/tools

export PROXYCHAINS_CONF_FILE=$XDG_CONFIG_HOME/proxychains/proxychains.conf
# }}}

# {{{1 BindKeys
# bindkey -e # emacs mode
# bindkey -v # vi mode
# bindkey "^?" backward-delete-char # https://zsh.sourceforge.io/Intro/intro_11.html
# use `showkey -a` to print the key codes
# bindkey "^k" up-line-or-history
# bindkey "^j" down-line-or-history
# bindkey "^p" up-line-or-history
# bindkey "^n" down-line-or-history
# bindkey '^a' beginning-of-line
# bindkey '^e' end-of-line
# bindkey '^h' backward-char
# bindkey '^l' forward-char
# }}}

# {{{1 Plugins
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

	git_clone_or_update https://github.com/agkozak/zsh-z $HOME/.zsh-plugins/zsh-z
	git_clone_or_update https://github.com/jocelynmallon/zshmarks $HOME/.zsh-plugins/zshmarks
	git_clone_or_update https://github.com/jeffreytse/zsh-vi-mode $HOME/.zsh-plugins/zsh-vi-mode

	git_clone_or_update https://github.com/hutusi/git-paging.git $HOME/.zsh-plugins/git-paging
	ln -svf $HOME/.zsh-plugins/git-paging/git-* $HOME/.local/bin
}

# https://github.com/zsh-users/zsh-autosuggestions
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source $HOME/.zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^f' forward-word

# https://github.com/zsh-users/zsh-syntax-highlighting
source $HOME/.zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# completion https://thevaluable.dev/zsh-completion-guide-examples
if [[ $OS == darwin ]]; then
    if type brew &>/dev/null
    then
	FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

	autoload -Uz compinit
	compinit
    fi
fi
source $ZDOTDIR/zsh-conf/completion.zsh

# https://github.com/agkozak/zsh-z
# source $HOME/.zsh-plugins/zsh-z/zsh-z.plugin.zsh

# https://github.com/jocelynmallon/zshmarks
source $HOME/.zsh-plugins/zshmarks/init.zsh
fmarks() {
    if [[ -f "$BOOKMARKS_FILE" ]]; then
        lines=$(cat $BOOKMARKS_FILE)
        bookmarkpath=$(echo $lines | fzf | cut -d "|" -f1)
        bookmarkpath="${bookmarkpath/'$HOME'/$HOME}" # replace $HOME in string
        cd $bookmarkpath
    else
        echo "BOOKMARKS_FILE does not exist"
    fi
}
# alias bm="bookmark"
# alias bmj="jump"
# alias bmd="deletemark"
# alias bml="fmarks"
alias m="fmarks"
alias ma="bookmark"
alias md="deletemark"

# https://github.com/jeffreytse/zsh-vi-mode
function zvm_config() {
    ZVM_VI_INSERT_ESCAPE_BINDKEY=jj

    ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
    ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
    # ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
}
source $HOME/.zsh-plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh
zvm_bindkey vicmd '^e' zvm_vi_edit_command_line
# }}}

# {{{1 Zsh Directory Stack
# https://zsh.sourceforge.io/Intro/intro_6.html
setopt AUTO_PUSHD           # Push the current directory visited on the stack.
setopt PUSHD_IGNORE_DUPS    # Do not store duplicates in the stack.
setopt PUSHD_SILENT         # Do not print the directory stack after pushd or popd.
for index ({1..9}) alias "$index"="cd +${index}"; unset index
alias d='dirs -v'
# }}}

# {{{1 User Configuration
sources=(
    'functions'
    'aliases'
    'git'
    'tmux'
)

for s in "${sources[@]}"; do
    source $ZDOTDIR/zsh-conf/${s}.zsh
done

[ -f $ZDOTDIR/zsh-conf/custom.zsh ] && source $ZDOTDIR/zsh-conf/custom.zsh
# }}}

# {{{1 Golang
export GO111MODULE=on
# export GOPROXY=https://goproxy.io,https://proxy.golang.org,direct
# export GOSUMDB=gosum.io+ce6e7565+AY5qEHUk/qmHc5btzW45JVoENfazw8LielDsaI+lEbq6
export GOPATH=$LIU_ENV/golang/gopath
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN
export PATH=$PATH:$HOME/env/golang/go/bin


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

function gopprof() {
	go tool pprof -http=$HOSTIP:7788 -no_browser $@
}
# }}}

# {{{1 Rust
export RUSTUP_HOME=$LIU_ENV/rust/rustup

export CARGO_HOME=$LIU_ENV/rust/cargo
export CARGO_BIN=$LIU_ENV/rust/cargo/bin
export PATH=$PATH:$CARGO_BIN
# }}}

# Nodejs {{{
export PATH=$PATH:$HOME/env/nodejs/node/bin
# }}}

# {{{1 Path
# https://zsh.sourceforge.io/Guide/zshguide02.html#l24
typeset -U path

export PATH=$PATH:$HOME/bin:$HOME/.local/bin

if [[ $OS == darwin ]]; then
    export PATH=$PATH:/opt/homebrew/bin
fi

# Remove duplicate env var
# export PATH=$(echo $PATH | tr : "\n" | sort | uniq | tr "\n" :)
# }}}

# {{{1 Tools Configuration
## starship
export STARSHIP_CONFIG=$ZDOTDIR/starship/starship.toml
[ -f "$(which starship)" ] && eval "$(starship init zsh)"

## direnv
[ -f "$(which direnv)" ] && eval "$(direnv hook zsh)"

## fzf
export FZF_DEFAULT_OPTS='--height 50% --border --reverse'
### https://minsw.github.io/fzf-color-picker
### https://github.com/ianchesal/nord-fzf
### https://github.com/junegunn/fzf/blob/master/ADVANCED.md#color-themes
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color=fg:#e5e9f0,bg:#2E3440,hl:#81a1c1
--color=fg+:#e5e9f0,bg+:#2E3440,hl+:#81a1c1
--color=info:#eacb8a,prompt:#bf6069,pointer:#b48dac
--color=marker:#a3be8b,spinner:#b48dac,header:#a3be8b'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

## zoxide
[ -f "$(which zoxide)" ] && eval "$(zoxide init zsh)" # must be added after compinit is called.

## tmuxp
export TMUXP_CONFIGDIR=$XDG_CONFIG_HOME/tmuxp
# }}}

## vim: foldmethod=marker foldlevel=3
