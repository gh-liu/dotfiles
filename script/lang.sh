#! /bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. $SCRIPT_DIR/helper.sh --source-only

function update_go() {
	need_cmd jq

	GOVERSION="$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0].version')"
	GOARCH="$(normalize_arch "$(uname -m)")"
	echo "updating to $GOVERSION (linux-$GOARCH) ..."

	mkdir_env_dir golang
	download "https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz" "$GOVERSION.linux-$GOARCH.tar.gz" || {
		echo "fail to download go" >&2
		return 1
	}
	backup go
	tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz
}

function update_gopls_dlv() {
	export GOPROXY=https://goproxy.io

	# local GOPLSVERSION=$(curl -s https://api.github.com/repos/golang/tools/releases | jq -r ".[0].tag_name" | cut -d/ -f2)
	# go install golang.org/x/tools/gopls@$GOPLSVERSION
	go install golang.org/x/tools/gopls@latest
	go install github.com/go-delve/delve/cmd/dlv@latest
}
function update_zig() {
	need_cmd jq

	# Zig download keys use "x86_64-linux" / "aarch64-linux" naming.
	local machine arch_key
	machine="$(uname -m)"
	case "$machine" in
	x86_64) arch_key="x86_64-linux" ;;
	aarch64 | arm64) arch_key="aarch64-linux" ;;
	*) arch_key="${machine}-linux" ;;
	esac

	# tmpfile="/tmp/zig-index-$$"
	# curl -s -o "$tmpfile" https://ziglang.org/download/index.json
	# zig_url="$(jq -r ".master.\"$arch_key\".tarball" "$tmpfile")"
	# VERSION="$(jq -r 'to_entries[1].value.version' "$tmpfile")"

	mkdir_env_dir zig

	tmpfile="$LIU_ENV/zig/info.json"
	curl -s https://ziglang.org/download/index.json |
		# jq '.master' \
		jq 'to_entries[1].value' \
			>"$tmpfile"

	VERSION="$(jq -r '.version' "$tmpfile")"
	ZIGURL="$(jq -r ".\"$arch_key\".tarball" "$tmpfile")"
	echo "updating to $VERSION ($arch_key) ..."

	local pkg
	pkg="$(basename "$ZIGURL")"
	download "$ZIGURL" "$pkg" || {
		echo "fail to download zig" >&2
		return 1
	}
	backup zig
	tar xvJf "$pkg"
	rm "$pkg"
	mv "zig-${arch_key}-$VERSION" zig
}

function update_zls() {
	# Ensure zig exists (installed by update_zig and linked into ~/.local/bin).
	if ! command -v zig >/dev/null 2>&1; then
		echo "zig not found; installing zig first..." >&2
		update_zig || return 1
	fi

	mkdir_env_dir zls

	git_clone_or_update https://github.com/zigtools/zls "$LIU_ENV/zig/zls"

	zig build -Doptimize=ReleaseSafe
	[[ $? -ne 0 ]] && echo "fail to build zls" >&2 && return 1

	chmod +x "$(pwd)/zig-out/bin/zls"
	link_bin "$(pwd)/zig-out/bin/zls" zls
}

function update_rust() {
	mkdir_env_dir rust
	export RUSTUP_HOME=$LIU_ENV/rust/rustup
	export CARGO_HOME=$LIU_ENV/rust/cargo

	if command -v rustup >/dev/null 2>&1; then
		rustup update
	else
		curl https://sh.rustup.rs -sSf | sh
		rustup component add rust-analyzer rust-src
		# rustup component add llvm-tools-preview
	fi
	# ln -svf $(rustup which --toolchain stable rust-analyzer) $CARGO_HOME/bin/rust-analyzer
}

function update_pnpm() {
	if ! command -v pnpm >/dev/null 2>&1; then
		curl -fsSL https://get.pnpm.io/install.sh | sh -
	fi
}

function update_bun() {
	mkdir_env_dir nodejs

	# export BUN_INSTALL="$LIU_ENV/nodejs/bun"
	if ! command -v bun >/dev/null 2>&1; then
		curl -fsSL https://bun.sh/install | bash
	else
		bun upgrade
	fi
}

function update_nvm() {
	## nvm: nodejs
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
}

function update_nodejs() {
	_install_start nodejs

	NODEJSVERSION=$(curl -s https://api.github.com/repos/nodejs/node/tags | jq -r '.[0].name')
	NODEJSARCH=x64
	echo "updating to $NODEJSVERSION($NODEJSARCH) ..."

	mkdir_env_dir nodejs
	NODEJSINSTALLHOME=$LIU_ENV/nodejs

	wget https://nodejs.org/dist/$NODEJSVERSION/node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz -q --show-progress -P $NODEJSINSTALLHOME
	[[ $? -ne 0 ]] && echo "fail to download nodejs" >&2 && return 1

	xz -d node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz
	tar -xvf node-$NODEJSVERSION-linux-$NODEJSARCH.tar
	rm -rf node
	mv node-$NODEJSVERSION-linux-$NODEJSARCH node
	rm node-$NODEJSVERSION-linux-$NODEJSARCH.tar

	echo "updating npm..."
	npm install npm@latest -g

	_install_end
}

function install_uv() {
	# or https://www.build-python-from-source.com

	# or  https://github.com/pyenv/pyenv
	# curl https://pyenv.run | bash

	# https://docs.astral.sh/uv

	mkdir_env_dir python
	export UV_INSTALL_DIR=$LIU_ENV/python/uv
	if ! command -v uv >/dev/null 2>&1; then
		curl -LsSf https://astral.sh/uv/install.sh | sh
		uv python install 3.12
	else
		uv self update
	fi

	# NOTE: Use venv in python2
	# 1. pip install virtualenv
	# 2. virtualenv -p $(which python2) myenv
	# 3. source myenv/bin/activate
}

function install_uv_tools() {
	uv tool install ruff
	uv tool install ty
}

case $1 in
"go")
	_install_start go
	update_go
	update_gopls_dlv
	_install_end
	;;
"python")
	_install_start uv
	install_uv
	install_uv_tools
	_install_end
	;;
"zig")
	_install_start zig
	update_zig
	update_zls
	_install_end
	;;
"rust")
	_install_start rust
	update_rust
	_install_end
	;;
"nodejs")
	# update_nodejs
	_install_start bun
	update_bun
	_install_end
	update_nvm
	;;
*)
	echo "select one language"
	;;
esac
