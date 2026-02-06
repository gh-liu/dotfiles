# fzf completion for wt switch and wt remove
_fzf_complete_wt() {
	local tokens=(${(z)LBUFFER})
	local cmd=${tokens[2]-}
	
	if [[ "$cmd" == "switch" || "$cmd" == "remove" ]]; then
		_fzf_complete -m -- "$@" < <(git worktree list 2>/dev/null | awk '{match($0, /\[(.+)\]/, arr); if (arr[1]) print arr[1]}')
	fi
}
