[[ "${OS:-}" == darwin ]] || return 0

homebrew_source_mode="${HOMEBREW_SOURCE_MODE:-all}"

if [[ -z "${HOMEBREW_RESOLVED_PREFIX:-}" ]]; then
	HOMEBREW_RESOLVED_PREFIX="${HOMEBREW_PREFIX:-}"
	if [[ -z "$HOMEBREW_RESOLVED_PREFIX" ]]; then
		if [[ -d /opt/homebrew ]]; then
			HOMEBREW_RESOLVED_PREFIX=/opt/homebrew
		elif [[ -d /usr/local ]]; then
			HOMEBREW_RESOLVED_PREFIX=/usr/local
		fi
	fi
fi

if [[ "$homebrew_source_mode" != path && -n "$HOMEBREW_RESOLVED_PREFIX" && -z "${HOMEBREW_FPATH_CONFIGURED:-}" ]]; then
	# Prefer HOMEBREW_PREFIX when present, then fall back to common default prefixes.
	[[ -d "$HOMEBREW_RESOLVED_PREFIX/share/zsh/site-functions" ]] && \
		fpath=("$HOMEBREW_RESOLVED_PREFIX/share/zsh/site-functions" $fpath)
	typeset -g HOMEBREW_FPATH_CONFIGURED=1
fi

if [[ "$homebrew_source_mode" != fpath && -n "$HOMEBREW_RESOLVED_PREFIX" && -z "${HOMEBREW_PATH_CONFIGURED:-}" ]]; then
	[[ -d "$HOMEBREW_RESOLVED_PREFIX/bin" ]] && path+=("$HOMEBREW_RESOLVED_PREFIX/bin")
	export HOMEBREW_BUNDLE_FILE="$XDG_CONFIG_HOME/Brewfile"
	typeset -g HOMEBREW_PATH_CONFIGURED=1
fi

unset homebrew_source_mode
