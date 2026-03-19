#! /bin/bash

# ======= helper
: "${OS:=$(uname -s | tr '[:upper:]' '[:lower:]')}"
: "${ARCH:=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')}"
have_cmd() { command -v "$1" >/dev/null 2>&1; }
backup_existing() {
	local target="$1" backup="${2:-$1.bak}"
	[[ -e "$target" ]] || return 0
	rm -rf "$backup"
	mv "$target" "$backup"
}
cdenv() {
	local d="${LIU_ENV:-$HOME/env}/$1"
	mkdir -p "$d" && cd "$d" && pwd
}
link_bin() { mkdir -p "$HOME/.local/bin" && ln -svf "$1" "$HOME/.local/bin/$2"; }
download() {
	local url="$1" out="${2:-}"
	[[ -n "$out" ]] && mkdir -p "$(dirname "$out")"
	curl -fL --retry 3 --connect-timeout 10 ${out:+-o "$out"} ${out:-"-O"} "$url"
}
gh_latest_tag() {
	gh release list --json tagName,isLatest --jq '.[] | select(.isLatest) | .tagName' -R "$1"
}
gh_download() {
	gh release download "$2" -R "$1" -p "$3"
}
# ======= helper

install_go() {
	# 1. version
	local version
	version="$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0].version')"
	# 2. info
	echo "updating to $version (${OS}-${ARCH}) ..."
	# 3. env dir
	cdenv golang
	# 4. package
	local pkg="$version.${OS}-${ARCH}.tar.gz"
	# 5. download
	download "https://dl.google.com/go/$pkg" "$pkg" || {
		echo "fail to download go" >&2
		return 1
	}
	# 6. extract
	backup_existing go
	tar -zxvf "$pkg"
	# 7. finalize
	export GOPROXY=https://goproxy.io
	go install golang.org/x/tools/gopls@latest
	go install github.com/go-delve/delve/cmd/dlv@latest
}

install_zls() {
	local zls_os
	case "$OS" in
	darwin) zls_os="macos" ;;
	*) zls_os="$OS" ;;
	esac
	local zls_arch
	case "$(uname -m)" in
	x86_64) zls_arch="x86_64" ;;
	aarch64 | arm64) zls_arch="aarch64" ;;
	*) zls_arch="$(uname -m)" ;;
	esac

	# 1. version
	local version
	version="$(gh_latest_tag zigtools/zls)"
	# 2. info
	echo "updating to $version (${zls_arch}-${zls_os}) ..."
	# 3. env dir
	cdenv zig
	# 4. package
	local pkg="zls-${zls_arch}-${zls_os}.tar.xz"
	# 5. download
	gh_download zigtools/zls "$version" "$pkg" || {
		echo "fail to download zls" >&2
		return 1
	}
	# 6. extract
	tar xvJf "$pkg"
	# 7. finalize
	rm "$pkg"
	chmod +x zls
	link_bin "$(pwd)/zls" zls
}

install_zig() {
	local arch_key
	case "$(uname -m)" in
	x86_64) arch_key="x86_64-${OS}" ;;
	aarch64 | arm64) arch_key="aarch64-${OS}" ;;
	*) arch_key="$(uname -m)-${OS}" ;;
	esac

	# 1. version
	local tmpfile="/tmp/zig-index-$$"
	curl -s https://ziglang.org/download/index.json | jq 'to_entries[1].value' >"$tmpfile"
	local version url
	version="$(jq -r '.version' "$tmpfile")"
	url="$(jq -r ".\"$arch_key\".tarball" "$tmpfile")"
	rm -f "$tmpfile"
	# 2. info
	echo "updating to $version ($arch_key) ..."
	# 3. env dir
	cdenv zig
	# 4. package
	local pkg="$(basename "$url")"
	# 5. download
	download "$url" "$pkg" || {
		echo "fail to download zig" >&2
		return 1
	}
	# 6. extract
	tar xvJf "$pkg"
	# 7. finalize
	rm "$pkg"
	backup_existing zig
	mv "zig-${arch_key}-$version" zig

	install_zls
}

install_rust() {
	local dir=$(cdenv rust)
	export RUSTUP_HOME=$dir/rustup
	export CARGO_HOME=$dir/cargo

	if have_cmd rustup; then
		rustup update
	else
		curl https://sh.rustup.rs -sSf | sh
		rustup component add rust-analyzer rust-src
	fi
}

install_bun() {
	local dir
	dir="$(cdenv nodejs)"
	export BUN_INSTALL="$dir/bun"

	if have_cmd bun; then
		bun upgrade
	else
		curl -fsSL https://bun.sh/install | bash
	fi
}

install_uv() {
	local dir
	dir="$(cdenv python)"
	export UV_INSTALL_DIR=$dir/uv

	if have_cmd uv; then
		uv self update
	else
		curl -LsSf https://astral.sh/uv/install.sh | sh
		uv python install 3.12
	fi

	uv tool install ruff
	uv tool install ty
}

if [[ -z "$1" ]]; then
	echo "select one language: go | uv | zig | rust | bun"
elif declare -f "install_$1" >/dev/null; then
	echo "======== installing $1 ========"
	install_"$1"
else
	echo "unknown language: $1" >&2
	exit 1
fi
