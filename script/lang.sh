#! /bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. $SCRIPT_DIR/helper.sh --source-only

function update_go() {
	install_start go

	need_cmd jq
	GOVERSION="$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0].version')"
	GOARCH="$(normalize_arch "$(uname -m)")"
	echo "updating to $GOVERSION (linux-$GOARCH) ..."

	mkdir_env_dir golang
	backup go

	download "https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz" "$GOVERSION.linux-$GOARCH.tar.gz" || {
		echo "fail to download go" >&2
		return 1
	}

	tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz

	install_end
}

function update_gopls_dlv() {
	export GOPROXY=https://goproxy.io

	install_start gopls
	# local GOPLSVERSION=$(curl -s https://api.github.com/repos/golang/tools/releases | jq -r ".[0].tag_name" | cut -d/ -f2)
	# go install golang.org/x/tools/gopls@$GOPLSVERSION
	go install golang.org/x/tools/gopls@latest
	install_end

	install_start dlv
	go install github.com/go-delve/delve/cmd/dlv@latest
	install_end
}

function update_golangci-lint() {
	install_start golangci-lint

	version="$(github_latest_release_tag golangci golangci-lint)"
	[[ -z "$version" ]] && echo "fail to resolve golangci-lint version" >&2 && return 1
	echo "version $version..."
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin $version

	install_end
}

function update_zig() {
	install_start zig

	need_cmd jq

	# Zig download keys use "x86_64-linux" / "aarch64-linux" naming.
	local machine arch_key
	machine="$(uname -m)"
	case "$machine" in
	x86_64) arch_key="x86_64-linux" ;;
	aarch64 | arm64) arch_key="aarch64-linux" ;;
	*) arch_key="${machine}-linux" ;;
	esac

	VERSION="$(curl -s https://ziglang.org/download/index.json | jq -r '.master."version"')"
	echo "updating to $VERSION ($arch_key) ..."

	mkdir_env_dir zig
	backup zig

	local zig_url pkg
	zig_url="$(curl -s https://ziglang.org/download/index.json | jq -r ".master.\"$arch_key\".tarball")"
	pkg="$(basename "$zig_url")"

	if [[ -z "$zig_url" || "$zig_url" == "null" ]]; then
		echo "fail to resolve zig tarball for arch key: $arch_key" >&2
		return 1
	fi

	download "$zig_url" "$pkg" || {
		echo "fail to download zig" >&2
		return 1
	}

	tar xvJf "$pkg"
	rm "$pkg"
	mv "zig-${arch_key}-$VERSION" zig

	link_bin "$(pwd)/zig/zig" zig

	install_end
}

function update_zls() {
	install_start zls

	# Ensure zig exists (installed by update_zig and linked into ~/.local/bin).
	if ! command -v zig >/dev/null 2>&1; then
		echo "zig not found; installing zig first..." >&2
		update_zig || return 1
	fi

	mkdir_env_dir zls

	git_clone_or_update https://github.com/zigtools/zls "$LIU_ENV/zls"

	zig build -Doptimize=ReleaseSafe
	[[ $? -ne 0 ]] && echo "fail to build zls" >&2 && return 1

	chmod +x "$(pwd)/zig-out/bin/zls"

	link_bin "$(pwd)/zig-out/bin/zls" zls

	install_end
}

function update_rust() {
	install_start rust

	if command -v rustup >/dev/null 2>&1; then
		rustup update
	else
		curl https://sh.rustup.rs -sSf | sh
		rustup component add rust-analyzer rust-src
		rustup component add llvm-tools-preview
	fi
	# ln -svf $(rustup which --toolchain stable rust-analyzer) $CARGO_HOME/bin/rust-analyzer

	install_end
}

function update_codelldb() {
	install_start codelldb

	version="$(github_latest_release_tag vadimcn codelldb)"
	[[ -z "$version" ]] && echo "fail to resolve codelldb version" >&2 && return 1
	echo "version codelldb-$version..."

	# LET NVIM DAP KNOW THE PATH
	mkdir_env_dir codelldb

	local machine pkg
	machine="$(uname -m)"
	case "$machine" in
	x86_64) pkg="codelldb-linux-x64.vsix" ;;
	aarch64 | arm64) pkg="codelldb-linux-arm64.vsix" ;;
	*) pkg="codelldb-linux-x64.vsix" ;;
	esac
	github_download vadimcn codelldb "$version" "$pkg" "$pkg" || {
		echo "fail to download codelldb" >&2
		return 1
	}

	unzip $pkg
	link_bin $(pwd)/extension/adapter/codelldb codelldb

	install_end
}

function update_lua() {
	install_start lua

	need_cmd jq
	LUAVERSION=$(curl -s https://api.github.com/repos/lua/lua/tags | jq -r '.[0].name')
	LUAVERSION="${LUAVERSION:1}"
	echo "version lua-$LUAVERSION ..."

	mkdir_env_dir lua
	LUAINSTALLHOME=$LIU_ENV/lua

	download "https://www.lua.org/ftp/lua-$LUAVERSION.tar.gz" "lua-$LUAVERSION.tar.gz" || {
		echo "fail to download lua" >&2
		return 1
	}

	tar -zxvf lua-$LUAVERSION.tar.gz
	mv lua-$LUAVERSION lua
	rm -rf lua-$LUAVERSION.tar.gz

	cd lua
	make all test

	link_bin $LUAINSTALLHOME/lua/src/lua lua
	link_bin $LUAINSTALLHOME/lua/src/luac luac

	install_end
}

function update_luals() {
	install_start luals

	version="$(github_latest_release_tag LuaLS lua-language-server)"
	[[ -z "$version" ]] && echo "fail to resolve luals version" >&2 && return 1
	echo "version luals-$version..."

	mkdir_env_dir luals

	pkg="lua-language-server-$version-linux-x64.tar.gz"

	github_download LuaLS lua-language-server "$version" "$pkg" "$pkg" || {
		echo "fail to download luals" >&2
		return 1
	}

	tar -zxvf ./$pkg
	link_bin $(pwd)/bin/lua-language-server lua-language-server

	install_end
}

function update_luarocks() {
	install_start luarocks

	LUAROCKSVERSION="$(github_latest_release_tag luarocks luarocks)"
	[[ -z "$LUAROCKSVERSION" ]] && echo "fail to resolve luarocks version" >&2 && return 1
	LUAROCKSVERSION="${LUAROCKSVERSION#v}"
	echo "updating to $LUAROCKSVERSION ..."

	mkdir_env_dir luarocks

	download "https://luarocks.org/releases/luarocks-$LUAROCKSVERSION.tar.gz" "luarocks-$LUAROCKSVERSION.tar.gz" || {
		echo "fail to download luarocks" >&2
		return 1
	}

	tar zxpf luarocks-$LUAROCKSVERSION.tar.gz
	rm luarocks-$LUAROCKSVERSION.tar.gz
	mv luarocks-$LUAROCKSVERSION luarocks

	cd luarocks
	./configure --with-lua-include=$LIU_ENV/lua/lua/src
	make && sudo make install

	sudo luarocks install luasocket
	sudo luarocks install busted # test

	install_end
}

function update_pnpm() {
	if ! command -v pnpm >/dev/null 2>&1; then
		curl -fsSL https://get.pnpm.io/install.sh | sh -
	fi
}

function update_bun() {
	if ! command -v bun >/dev/null 2>&1; then
		curl -fsSL https://bun.sh/install | bash
	else
		bun upgrade
	fi
}

function update_nodejs() {
	install_start nodejs

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

	install_end
}

function install_uv() {
	# or https://www.build-python-from-source.com

	# or  https://github.com/pyenv/pyenv
	# curl https://pyenv.run | bash

	# https://docs.astral.sh/uv

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

case $1 in
"go")
	update_go
	update_gopls_dlv
	update_golangci-lint
	;;
"zig")
	update_zig
	update_zls
	;;
"rust")
	update_rust
	update_codelldb
	;;
"lua")
	update_lua
	update_luals
	update_luarocks
	;;
"nodejs")
	# update_nodejs
	update_bun
	;;
"python")
	install_uv
	;;
*)
	echo "select one language"
	;;
esac
