# fzf completion for bun run
_fzf_complete_bun() {
	local tokens=(${(z)LBUFFER})
	local cmd=${tokens[2]-}

	if [[ "$cmd" == "run" ]]; then
		_fzf_complete -- "$@" < <(jq -r '.scripts // {} | keys[]' package.json 2>/dev/null)
	fi
}
