#! /bin/bash

# NOTE:
# - This file is sourced by other scripts. Avoid setting global shell options
#   like `set -e` here; instead keep helpers robust and return non-zero on error.

: "${LIU_ENV:=$HOME/env}"
: "${LIU_TOOLS:=$HOME/tools}"

die() {
	echo "ERROR: $*" >&2
	return 1
}

have_cmd() {
	command -v "$1" >/dev/null 2>&1
}

need_cmd() {
	have_cmd "$1" || die "missing required command: $1"
}

normalize_arch() {
	# Map `uname -m` to common download arch names.
	local arch="${1:-$(uname -m)}"
	case "$arch" in
	x86_64) echo amd64 ;;
	aarch64 | arm64) echo arm64 ;;
	*) echo "$arch" ;;
	esac
}

download() {
	# download <url> [output_path]
	local url="$1"
	local out="${2:-}"

	if [[ -n "$out" ]]; then
		mkdir -p "$(dirname "$out")" || return 1
	fi

	if have_cmd curl; then
		if [[ -n "$out" ]]; then
			curl -fL --retry 3 --retry-delay 1 --connect-timeout 10 -o "$out" "$url"
		else
			curl -fL --retry 3 --retry-delay 1 --connect-timeout 10 -O "$url"
		fi
		return $?
	fi

	if have_cmd wget; then
		if [[ -n "$out" ]]; then
			wget "$url" -q --show-progress -O "$out"
		else
			wget "$url" -q --show-progress
		fi
		return $?
	fi

	die "neither curl nor wget is available"
}

github_download() {
	# github_download <user> <repo> <tag> <asset_name> [output_path]
	local user="$1"
	local repo="$2"
	local version="$3"
	local release="$4"
	local out="${5:-$release}"
	download "https://github.com/$user/$repo/releases/download/$version/$release" "$out"
}

github_latest_release_tag() {
	# github_latest_release_tag <user> <repo>
	# Avoid GitHub API rate limits by following the /releases/latest redirect.
	local user="$1"
	local repo="$2"
	local loc
	loc="$(curl -fsSI --connect-timeout 10 --max-time 20 "https://github.com/$user/$repo/releases/latest" | awk -F': ' 'tolower($1)=="location"{print $2}' | tr -d '\r' | tail -n1)"
	[[ -z "$loc" ]] && return 1
	echo "${loc##*/}"
}

git_clone_or_update() {
	local repo="$1"
	local dir="$2"
	if [[ -d "$dir/.git" ]]; then
		( cd "$dir" && git pull )
	else
		git clone "$repo" "$dir"
	fi
}

install_start() {
	echo "========================================"
	echo "Installing $1..."
}

install_end() {
	echo "========================================"
}

mkdir_tool_dir() {
	local tool="$1"
	mkdir -p "$LIU_TOOLS/$tool" && cd "$LIU_TOOLS/$tool"
}

mkdir_env_dir() {
	local env="$1"
	mkdir -p "$LIU_ENV/$env" && cd "$LIU_ENV/$env"
}

backup() {
	# backup <path_basename> (in current working directory)
	local name="$1"
	if [[ -e "$(pwd)/$name" ]]; then
		mv "$(pwd)/$name" "$(pwd)/${name}.$(date +%s)"
	fi
}

link_bin() {
	mkdir -p "$HOME/.local/bin"
	ln -svf "$1" "$HOME/.local/bin/$2"
}
