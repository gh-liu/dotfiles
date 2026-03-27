# fzf completion for gh pr
_fzf_complete_gh() {
	local tokens=(${(z)LBUFFER})
	local cmd=${tokens[2]-}
	local sub=${tokens[3]-}

	if [[ "$cmd" != "pr" ]]; then
		return
	fi

	case "$sub" in
	checkout|checks|close|merge|ready|review)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(gh pr list --state open 2>/dev/null)
		;;
	reopen)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(gh pr list --state closed 2>/dev/null)
		;;
	comment|diff|edit|lock|unlock|view)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(gh pr list --state all 2>/dev/null)
		;;
	esac
}

_fzf_complete_gh_post() {
	awk '{ print $1 }'
}
