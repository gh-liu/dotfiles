[[ -n "${FZF_CONFIGURED:-}" ]] && return 0

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

if (( $+commands[fd] )); then
	_fzf_compgen_path() {
		fd --color never --hidden --follow --exclude ".git" . "$1"
	}
	_fzf_compgen_dir() {
		fd --type d --color never --hidden --follow --exclude ".git" . "$1"
	}
fi

if [[ -z "${FZF_SHELL_INITIALIZED:-}" ]] && (( $+commands[fzf] )) && [[ -o interactive ]] && [[ -t 0 && -t 1 ]]; then
	source <(fzf --zsh)
	typeset -g FZF_SHELL_INITIALIZED=1
fi

for _fzf_completion in $ZDOTDIR/fzf-completions/*.zsh; do
	[ -f "$_fzf_completion" ] && source "$_fzf_completion"
done
unset _fzf_completion

typeset -g FZF_CONFIGURED=1
