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

if test -n "${TMUX}"; then
	# https://github.com/von/homestuff/blob/b624fbcf5d5f4e385cbc75b57466f342ce36a977/home/dot_zsh.d/tmux.zsh#L69
	tmux-last-command-output() {
		# There doesn't seem to be any way to output the tux selection directly
		# to stdout, so we use a named pipe.
		local pipedir=$(mktemp -d -t tmux-lco)
		local pipefile="${pipedir}/fifo"
		mkfifo -m 600 ${pipefile}
		tmux copy-mode \; \
			send-keys -X previous-prompt -o \; \
			send-keys -X begin-selection \; \
			send-keys -X next-prompt \; \
			send-keys -X cursor-up \; \
			send-keys -X end-of-line \; \
			send-keys -X stop-selection \; \
			send-keys -X copy-pipe-and-cancel "cat > ${pipefile}"
		cat ${pipefile}
		# Clean up
		rm -f ${pipefile}
		rmdir -rf ${pipedir}
	}

	alias lco='tmux-last-command-output'

	# See:
	# https://github.com/tmux/tmux/issues/4259
	# https://github.com/tmux/tmux/issues/3734
	TMUX_COMMAND_OUTPUT_MARK=$'\e]133;C\e\\'

	# Mark the start of command output
	tmux-mark-command-start() {
		echo -ne ${TMUX_COMMAND_OUTPUT_MARK}
	}

	add-zsh-hook preexec tmux-mark-command-start
fi

# vim: foldmethod=marker
