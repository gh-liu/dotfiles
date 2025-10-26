#! /bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. $SCRIPT_DIR/helper.sh --source-only

function update_go() {
	install_start go

	GOVERSION=$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0]."files" | .[0].version')
	GOARCH=$(if [[ $(uname -m) == "x86_64" ]]; then echo amd64; else echo $(uname -m); fi)
	echo "updating to go-$GOVERSION($GOARCH) ..."

	mkdir_env_dir golang
	backup go

	wget "https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz" -q --show-progress
	test $? -eq 1 && echo "fial to download go" && return

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

	url="https://api.github.com/repos/golangci/golangci-lint/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "vesrion $version..."
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin $version

	install_end
}

function update_zig() {
	if [[ -f "$(which zvm)" ]]; then
		zvm i master
	else
		install_start zig

		VERSION=$(curl -s https://ziglang.org/download/index.json | jq -r '.master."version"')
		echo "updating to $VERSION ..."

		mkdir_env_dir zig
		backup zig

		wget $(curl -s https://ziglang.org/download/index.json | jq -r '.master."x86_64-linux".tarball') -q --show-progress
		test $? -eq 1 && echo "fial to download zig" && return

		tar xvJf zig-linux-x86_64-$VERSION.tar.xz
		rm zig-linux-x86_64-$VERSION.tar.xz
		mv zig-linux-x86_64-$VERSION zig

		link_bin $(pwd)/zig/zig zig

		install_end
	fi
}

function update_zls() {
	if [[ -f "$(which zvm)" ]]; then
		zvm i --zls master
	else
		install_start zls

		mkdir_env_dir zls

		git_clone_or_update https://github.com/zigtools/zls $LIU_ENV/zls

		zig build -Doptimize=ReleaseSafe
		test $? -eq 1 && echo "fial to build zls" && return

		chmod +x $(pwd)/zig-out/bin/zls

		link_bin $(pwd)/zig-out/bin/zls zls

		install_end
	fi
}

function update_rust() {
	install_start rust

	if [[ -f "$(which rustup)" ]]; then
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

	url="https://api.github.com/repos/vadimcn/codelldb/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "vesrion codelldb-$version..."

	# LET NVIM DAP KNOW THE PATH
	mkdir_env_dir codelldb

	pkg="codelldb-x86_64-linux.vsix"
	github_download vadimcn codelldb $version $pkg
	test $? -eq 1 && echo "fial to download codelldb" && return

	unzip $pkg
	link_bin $(pwd)/extension/adapter/codelldb codelldb

	install_end
}

function update_lua() {
	install_start lua

	LUAVERSION=$(curl -s https://api.github.com/repos/lua/lua/tags | jq -r '.[0].name')
	LUAVERSION="${LUAVERSION:1}"
	echo "version lua-$LUAVERSION ..."

	mkdir_env_dir lua
	LUAINSTALLHOME=$LIU_ENV/lua

	wget https://www.lua.org/ftp/lua-$LUAVERSION.tar.gz -q --show-progress
	test $? -eq 1 && echo "fial to download" && return

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

	url="https://api.github.com/repos/LuaLS/lua-language-server/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "version luals-$version..."

	mkdir_env_dir luals

	pkg="lua-language-server-$version-linux-x64.tar.gz"

	github_download LuaLS lua-language-server $version $pkg
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf ./$pkg
	link_bin $(pwd)/bin/lua-language-server lua-language-server

	install_end
}

function update_luarocks() {
	install_start luarocks

	LUAROCKSVERSION=$(curl -s https://api.github.com/repos/luarocks/luarocks/tags | jq -r '.[0].name')
	LUAROCKSVERSION="${LUAROCKSVERSION:1}"
	echo "updating to $LUAROCKSVERSION ..."

	mkdir_env_dir luarocks

	wget https://luarocks.org/releases/luarocks-$LUAROCKSVERSION.tar.gz -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

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
	if [[ ! -f "$(which pnpm)" ]]; then
		curl -fsSL https://get.pnpm.io/install.sh | sh -
	else
	fi
}

function update_bun() {
	if [[ ! -f "$(which bun)" ]]; then
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
	test $? -eq 1 && echo "fial to download" && return

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

	if [[ ! -f "$(which uv)" ]]; then
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
