#!/bin/zsh
# aliases{{{1
alias ta='tmux attach -t'
alias ts='tmux new-session -s'
alias tl='tmux list-sessions'

# alias tp='tmux popup -h 70% -w 70% -E'

alias {tmon,tn}='tmux set mouse on && echo "tmux: set mouse on"'
alias {tmof,tf}='tmux set mouse off && echo "tmux: set mouse off"'

# tmuxp{{{2
alias tp='tmuxp'
alias tpf='tmuxp freeze --force'
alias tpl='tmuxp load'
alias tpls='tmuxp ls'
# }}}
# }}}

# functions{{{1
# tmux new a session and switch to
tmuxns() {
	tmux new-session -d -s $1 && tmux switch -t $1
}

# tmux rename current session
tmuxrn() {
	name=$(tmux list-sessions | grep attached | cut -d: -f1)
	tmux rename-session -t $name $1
}

# https://github.com/Phantas0s/.dotfiles/blob/1d4ed8ee315317042edabfd27c8670fd8d6eb316/zsh/scripts_fzf.zsh#L69
ftmux() {
	if [[ ! -n $TMUX ]]; then
		# get the IDs
		ID="$(tmux list-sessions)"
		if [[ -z "$ID" ]]; then
			tmux new-session
		else
			create_new_session="Create New Session"
			ID="$ID\n${create_new_session}:"
			ID="$(echo $ID | fzf | cut -d: -f1)"
			if [[ "$ID" = "${create_new_session}" ]]; then
				tmux new-session
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
# }}}

# vim: foldmethod=marker
