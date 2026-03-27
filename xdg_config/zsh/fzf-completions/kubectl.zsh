# fzf completion for kubectl
_fzf_complete_kubectl() {
	local tokens=(${(z)LBUFFER})
	local cmd=${tokens[2]-}
	local sub=${tokens[3]-}

	case "$cmd" in
	get|describe|delete)
		if [[ -z "$sub" || "$sub" == "${tokens[-1]}" && ${#tokens[@]} -eq 3 ]]; then
			_fzf_complete -- "$@" < <(kubectl api-resources --cached --verbs=get -o name 2>/dev/null)
		else
			_fzf_complete --ansi --header-lines=1 -m -- "$@" < <(kubectl get "$sub" --no-headers 2>/dev/null | awk '{print $1}')
		fi
		;;
	logs|exec|attach)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(kubectl get pods 2>/dev/null)
		;;
	rollout)
		if [[ -z "$sub" ]]; then
			_fzf_complete -- "$@" < <(echo "history\npause\nrestart\nresume\nstatus\nundo")
		fi
		;;
	scale)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(kubectl get deployments 2>/dev/null)
		;;
	config)
		if [[ "$sub" == "use-context" || "$sub" == "delete-context" || "$sub" == "rename-context" || "$sub" == "set-context" ]]; then
			_fzf_complete -- "$@" < <(kubectl config get-contexts -o name 2>/dev/null)
		fi
		;;
	top)
		if [[ -z "$sub" ]]; then
			_fzf_complete -- "$@" < <(echo "nodes\npods")
		elif [[ "$sub" == "pods" ]]; then
			_fzf_complete --ansi --header-lines=1 -- "$@" < <(kubectl get pods 2>/dev/null)
		fi
		;;
	esac
}

_fzf_complete_kubectl_post() {
	awk '{ print $1 }'
}
