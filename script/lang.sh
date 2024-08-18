#! /usr/bin/bash
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
}

function update_zls() {
	install_start zls

	mkdir_env_dir zls

	git_clone_or_update https://github.com/zigtools/zls $LIU_ENV/zls

	zig build -Doptimize=ReleaseSafe
	test $? -eq 1 && echo "fial to build zls" && return

	chmod +x $(pwd)/zig-out/bin/zls

	link_bin $(pwd)/zig-out/bin/zls zls

	install_end
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

function update_python() {
	sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev tk-dev

	PYVERSION=$1
	MAJVERSION=$(echo $PYVERSION | cut -c1)
	BINVERSION=$2

	mkdir_env_dir python
	PYDIR=$LIU_ENV/python

	PYBINDIR=$LIU_ENV/python/bin
	mkdir -p $PYBINDIR

	wget "https://www.python.org/ftp/python/$PYVERSION/Python-$PYVERSION.tgz" -q --show-progress
	test $? -eq 1 && echo "fial to download $PYVERSION" && return

	sudo rm -rf $PYVERSION
	tar -xvzf Python-$PYVERSION.tgz
	mv Python-$PYVERSION $PYVERSION
	cd $PYVERSION

	PREFIX=$PYDIR/opt/python/$PYVERSION
	sudo rm -rf $PREFIX
	mkdir -p $PREFIX

	# https://www.build-python-from-source.com
	# https://devguide.python.org/getting-started/setup-building
	sudo ./configure --prefix=$PREFIX --enable-optimizations --with-lto --with-computed-gotos --with-system-ffi
	sudo make -j "$(nproc)"
	sudo make altinstall

	sudo $PREFIX/bin/python$BINVERSION -m pip install --upgrade pip setuptools wheel

	sudo ln -svf $PREFIX/bin/python$PYVERSION $PYBINDIR/python$MAJVERSION
	sudo ln -svf $PREFIX/bin/python$PYVERSION $PYBINDIR/python
	sudo ln -svf $PREFIX/bin/pip$PYVERSION $PYBINDIR/pip$MAJVERSION
	sudo ln -svf $PREFIX/bin/pip$PYVERSION $PYBINDIR/pip
	sudo ln -svf $PREFIX/bin/pydoc$PYVERSION $PYBINDIR/pydoc$MAJVERSION
	sudo ln -svf $PREFIX/bin/pydoc$PYVERSION $PYBINDIR/pydoc
	sudo ln -svf $PREFIX/bin/idle$PYVERSION $PYBINDIR/idle$MAJVERSION
	sudo ln -svf $PREFIX/bin/idle$PYVERSION $PYBINDIR/idle
	sudo ln -svf $PREFIX/bin/python$PYVERSION-config $PYBINDIR/python-config$MAJVERSION
	sudo ln -svf $PREFIX/bin/python$PYVERSION-config $PYBINDIR/python-config

	if [ "$MAJVERSION" == "2" ]; then
		sudo $PREFIX/bin/python$PYVERSION -m ensurepip --default-pip
	fi
}

function update_python3() {
	install_start python3

	PYVERSION="3.12.5"
	echo "updating to py-$PYVERSION ..."

	BINVERSION="3.12"

	update_python $PYVERSION $BINVERSION

	install_end
}

function update_python2() {
	install_start python2

	PYVERSION="2.7.18"
	echo "updating to py-$PYVERSION ..."

	BINVERSION="2.7"

	update_python $PYVERSION $BINVERSION

	install_end
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
	update_nodejs
	;;
"python3")
	update_python3
	;;
"python2")
	update_python2
	;;
*)
	echo "select one language"
	;;
esac
