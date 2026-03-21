#! /bin/bash

# ======= helper
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
	if [[ -n "$out" ]]; then
		mkdir -p "$(dirname "$out")" || return 1
		curl -fL --retry 3 --connect-timeout 10 -o "$out" "$url"
	else
		curl -fL --retry 3 --connect-timeout 10 -O "$url"
	fi
}
gh_latest_tag() {
	gh release list --json tagName,isLatest --jq '.[] | select(.isLatest) | .tagName' -R "$1"
}
gh_download() {
	gh release download "$2" -R "$1" -p "$3"
}
# ======= helper

install_go() {
	local os
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	local arch
	arch="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
	# 1. version
	local version; version="$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0].version')"
	# 2. info
	local pkg="$version.${os}-${arch}.tar.gz"
	local url="https://go.dev/dl/$pkg"
	echo "updating to $version (${os}-${arch}) from $url..."
	# 3. env dir
	cdenv golang
	# 4. download
	download "$url" "$pkg" || {
		echo "fail to download go" >&2
		return 1
	}
	# 5. extract
	backup_existing go
	tar -zxvf "$pkg"
	# 6. finalize
	export GOPROXY=https://goproxy.io
	go install golang.org/x/tools/gopls@latest
	go install github.com/go-delve/delve/cmd/dlv@latest
}

install_zls() {
	local os
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	local arch
	arch="$(uname -m | sed 's/arm64/aarch64/')"
	[[ "$os" == darwin ]] && os=macos

	# 1. version
	local version; version="$(gh_latest_tag zigtools/zls)"
	# 2. info
	local pkg="zls-${arch}-${os}.tar.xz"
	local url="https://github.com/zigtools/zls/releases/download/${version}/${pkg}"
	echo "updating to $version (${arch}-${os}) from $url..."
	# 3. env dir
	cdenv ziglang
	# 4. download
	gh_download zigtools/zls "$version" "$pkg" || {
		echo "fail to download zls" >&2
		return 1
	}
	# 5. extract
	tar xvJf "$pkg"
	# 6. finalize
	rm "$pkg"
	chmod +x zls
	link_bin "$(pwd)/zls" zls
}

install_zig() {
	local os
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	local arch
	arch="$(uname -m | sed 's/arm64/aarch64/')"
	local arch_key="${arch}-${os}"

	# 1. version
	local index; index="$(curl -s https://ziglang.org/download/index.json | jq 'to_entries[1].value')"
	local version; version="$(jq -r '.version' <<<"$index")"
	local url; url="$(jq -r ".\"$arch_key\".tarball" <<<"$index")"
	# 2. info
	echo "updating to $version ($arch_key) from $url..."
	# 3. env dir
	cdenv ziglang
	# 4. download
	local pkg; pkg="$(basename "$url")"
	download "$url" "$pkg" || {
		echo "fail to download zig" >&2
		return 1
	}
	# 5. extract
	tar xvJf "$pkg"
	# 6. finalize
	rm "$pkg"
	backup_existing zig
	mv "zig-${arch_key}-$version" zig

	install_zls
}

install_rust() {
	local dir
	dir="$(cdenv rust)"
	export RUSTUP_HOME="$dir/rustup"
	export CARGO_HOME="$dir/cargo"

	if have_cmd rustup; then
		rustup update
	else
		curl https://sh.rustup.rs -sSf | sh
		rustup component add rust-analyzer rust-src
	fi
}

install_bunjs() {
	local dir
	dir="$(cdenv nodejs)"
	export BUN_INSTALL="$dir/bun"

	if have_cmd bun; then
		bun upgrade
	else
		curl -fsSL https://bun.sh/install | bash
	fi
}

install_nodejs() {
	local os
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	local arch
	arch="$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')"
	local ext
	[[ "$os" == linux ]] && ext="tar.xz" || ext="tar.gz"

	# 1. version
	local version; version="$(gh_latest_tag nodejs/node)"
	# 2. info
	local pkg="node-${version}-${os}-${arch}.${ext}"
	local url="https://nodejs.org/dist/${version}/${pkg}"
	echo "updating to $version (${os}-${arch}) from $url..."
	# 3. env dir
	cdenv nodejs
	# 4. download
	download "$url" "$pkg" || {
		echo "fail to download nodejs" >&2
		return 1
	}
	# 5. extract
	backup_existing node
	if [[ "$ext" == "tar.xz" ]]; then
		tar xvJf "$pkg"
	else
		tar xvzf "$pkg"
	fi
	# 6. finalize
	rm "$pkg"
	mv "node-${version}-${os}-${arch}" node
}

install_emmylua_ls() {
	local os
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	local arch
	arch="$(uname -m | sed 's/aarch64/arm64/;s/x86_64/x64/')"

	# 1. version
	local version; version="$(gh_latest_tag EmmyLuaLs/emmylua-analyzer-rust)"
	# 2. info
	local pkg="emmylua_ls-${os}-${arch}.tar.gz"
	local url="https://github.com/EmmyLuaLs/emmylua-analyzer-rust/releases/download/${version}/${pkg}"
	echo "updating to $version (${os}-${arch}) from $url..."
	# 3. env dir
	cdenv lua
	# 4. download
	gh_download EmmyLuaLs/emmylua-analyzer-rust "$version" "$pkg" || {
		echo "fail to download emmylua_ls" >&2
		return 1
	}
	# 5. extract
	tar xvzf "$pkg"
	# 6. finalize
	rm "$pkg"
	chmod +x emmylua_ls
	link_bin "$(pwd)/emmylua_ls" emmylua_ls
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
	echo "select one language: go | uv | zig | rust | bunjs | emmylua_ls"
elif declare -f "install_$1" >/dev/null; then
	echo "======== installing $1 ========"
	install_"$1"
else
	echo "unknown language: $1" >&2
	exit 1
fi
