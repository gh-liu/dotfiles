update_zsh_completions() {
	mkdir -p "$XDG_CONFIG_HOME"/zsh/zsh-completions

	(($ + commands[gh])) && gh completion -s zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_gh
	(($ + commands[git - absorb])) && git-absorb --gen-completions zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_git-absorb

	(($ + commands[just])) && just --completions=zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_just
	(($ + commands[starship])) && starship completions zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_starship

	# (( $+commands[atuin] )) && atuin gen-completions --shell zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_atuin

	# (( $+commands[podman] )) && podman completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_podman
	# (( $+commands[docker] )) && docker completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_docker
	# (( $+commands[helm] )) && helm completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_helm
	# (( $+commands[kubectl] )) && kubectl completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_kubectl
	# (( $+commands[minikube] )) && minikube completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_minikube

	(($ + commands[rustc])) && cp "$(rustc --print sysroot)"/share/zsh/site-functions/_cargo "$XDG_CONFIG_HOME"/zsh/zsh-completions/_cargo
	(($ + commands[rustup])) && rustup completions zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_rustup
	(($ + commands[uv])) && uv generate-shell-completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_uv
	(($ + commands[uvx])) && uvx --generate-shell-completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_uvx
	(($ + commands[bun])) && SHELL=zsh bun completions >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_bun

	# (( $+commands[ollama] )) && curl https://gist.githubusercontent.com/obeone/9313811fd61a7cbb843e0001a4434c58/raw/_ollama.zsh \
	# 	>"$XDG_CONFIG_HOME"/zsh/zsh-completions/_ollama

	rm -f "$ZDOTDIR/.zcompdump" "$ZDOTDIR/.zcompdump.zwc"
}

## https://zsh.sourceforge.io/Doc/Release/Options.html#Completion-4
## https://zsh.sourceforge.io/Doc/Release/Completion-System.html
## man zshcompsys
## additional src: https://github.com/zsh-users/zsh-completions
USERPLUGINS+=(https://github.com/zsh-users/zsh-completions)
typeset -a _completion_fpath=(
	"$XDG_CONFIG_HOME/zsh/zsh-completions"
	"$HOME/.zsh-plugins/zsh-completions/src"
)
if [[ "${OS:-}" == darwin ]]; then
	typeset _homebrew_prefix="${HOMEBREW_RESOLVED_PREFIX:-${HOMEBREW_PREFIX:-}}"
	if [[ -z "$_homebrew_prefix" ]]; then
		if [[ -d /opt/homebrew ]]; then
			_homebrew_prefix=/opt/homebrew
		elif [[ -d /usr/local ]]; then
			_homebrew_prefix=/usr/local
		fi
	fi
	[[ -d "$_homebrew_prefix/share/zsh/site-functions" ]] && \
		_completion_fpath+=("$_homebrew_prefix/share/zsh/site-functions")
	unset _homebrew_prefix
fi
fpath=($_completion_fpath $fpath)
unset _completion_fpath

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
### NOTE: the sequence %F %f in the style's value to use a foreground color
### the sequence %K %k in the style's value to use a background color
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

autoload -U +X compinit
typeset _zcompdump="$ZDOTDIR/.zcompdump"
typeset -i _zcompdump_stale=0
if [[ ! -f "$_zcompdump" ]]; then
	_zcompdump_stale=1
else
	typeset _completion_file
	for _completion_file in "$XDG_CONFIG_HOME"/zsh/zsh-completions/_*; do
		[[ -e "$_completion_file" ]] || continue
		if [[ "$_completion_file" -nt "$_zcompdump" ]]; then
			_zcompdump_stale=1
			break
		fi
	done
fi

if ((_zcompdump_stale)); then
	compinit -d "$_zcompdump"
else
	compinit -C -d "$_zcompdump"
fi
unset _zcompdump _zcompdump_stale _completion_file
