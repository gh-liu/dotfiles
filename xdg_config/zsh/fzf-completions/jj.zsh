# fzf completion for jj
_fzf_complete_jj() {
	local tokens=(${(z)LBUFFER})
	local cmd=${tokens[2]-}
	local sub=${tokens[3]-}

	case "$cmd" in
	edit|abandon|describe|show|rebase|squash|diff|diffedit|duplicate|split|restore|revert|sign|absorb)
		_fzf_complete -- "$@" < <(jj log --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' -r 'all()' 2>/dev/null)
		;;
	bookmark)
		case "$sub" in
		delete|rename|set|track|untrack)
			_fzf_complete -- "$@" < <(jj bookmark list -T 'name ++ "\n"' 2>/dev/null)
			;;
		esac
		;;
	git)
		if [[ "$sub" == "push" || "$sub" == "fetch" ]]; then
			_fzf_complete -- "$@" < <(jj git remote list 2>/dev/null | awk '{print $1}')
		fi
		;;
	esac
}

_fzf_complete_jj_post() {
	awk '{ print $1 }'
}
