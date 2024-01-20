#! /usr/bin/bash

function update_gopls_dlv() {
	export GOPROXY=https://goproxy.io
	local GOPLSVERSION=$(curl -s https://api.github.com/repos/golang/tools/releases | jq -r ".[0].tag_name" | cut -d/ -f2)
	go install golang.org/x/tools/gopls@$GOPLSVERSION
	# go install golang.org/x/tools/gopls@latest
	go install github.com/go-delve/delve/cmd/dlv@latest
}

function update_go() {
	echo "go======================================BEGIN"

	GOVERSION=$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0]."files" | .[0].version')
	GOARCH=$(if [[ $(uname -m) == "x86_64" ]]; then echo amd64; else echo $(uname -m); fi)
	echo "updating to go-$GOVERSION($GOARCH) ..."

	GOINSTALLHOME=$LIU_ENV/golang
	mkdir -p $GOINSTALLHOME && cd $GOINSTALLHOME
	[ -d "$(pwd)/go" ] && rm -r $(pwd)/go

	wget "https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz" -q --show-progress
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz

	echo "========================================END"
}

function update_zls() {
	echo "zls=====================================BEGIN"

	ZLSINSTALLHOME=$LIU_ENV/zig/zls
	if [ -d $ZLSINSTALLHOME ]; then
		cd $ZLSINSTALLHOME
		git pull
	else
		mkdir -p $ZLSINSTALLHOME && cd $ZLSINSTALLHOME
		git clone https://github.com/zigtools/zls .
	fi
	zig build -Doptimize=ReleaseSafe
	test $? -eq 1 && echo "fial to build zls" && return
	chmod +x $(pwd)/zig-out/bin/zls
	sudo ln -svf $(pwd)/zig-out/bin/zls /usr/bin/zls

	echo "========================================END"
}

function update_zig() {
	echo "zig=====================================BEGIN"

	VERSION=$(curl -s https://ziglang.org/download/index.json | jq -r '.master."version"')
	echo "updating to $VERSION ..."

	ZIGINSTALLHOME=$LIU_ENV/zig
	mkdir -p $ZIGINSTALLHOME && cd $ZIGINSTALLHOME
	[ -d "$(pwd)/zig" ] && mv $(pwd)/zig $(pwd)/zig$(date +%s)

	wget $(curl -s https://ziglang.org/download/index.json | jq -r '.master."x86_64-linux".tarball') -q --show-progress
	test $? -eq 1 && echo "fial to download" && return
	tar xvJf zig-linux-x86_64-$VERSION.tar.xz
	rm zig-linux-x86_64-$VERSION.tar.xz
	mv zig-linux-x86_64-$VERSION zig

	sudo ln -svf $(pwd)/zig/zig /usr/bin/zig

	echo "========================================END"
}

function update_rust() {
	echo "========================================BEGIN"
	echo "rust........................................."
	if [[ -f "$(which rustup)" ]]; then
		rustup update
	else
		curl https://sh.rustup.rs -sSf | sh
		rustup component add rust-analyzer rust-src
		rustup component add llvm-tools-preview
	fi
	# ln -svf $(rustup which --toolchain stable rust-analyzer) $CARGO_HOME/bin/rust-analyzer
	echo "========================================END"
}

function update_codelldb() {
	echo "========================================BEGIN"
	url="https://api.github.com/repos/vadimcn/codelldb/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "Installing codelldb-$version..."

	[ -d $LIU_TOOLS/codelldb ] && rm -rf $LIU_TOOLS/codelldb
	mkdir -p $LIU_TOOLS/codelldb
	cd $LIU_TOOLS/codelldb

	pkg="codelldb-x86_64-linux.vsix"
	wget https://github.com/vadimcn/codelldb/releases/download/$version/$pkg -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	unzip $pkg

	echo "========================================END"
}

function update_luals() {
	echo "luals===================================BEGIN"

	url="https://api.github.com/repos/LuaLS/lua-language-server/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "Installing luals-$version..."

	[ -d $LIU_TOOLS/luals ] && mv $LIU_TOOLS/luals $LIU_TOOLS/luals$(date +%s)
	mkdir -p $LIU_TOOLS/luals
	cd $LIU_TOOLS/luals

	pkg="lua-language-server-$version-linux-x64.tar.gz"
	wget https://github.com/LuaLS/lua-language-server/releases/download/$version/$pkg -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf ./$pkg
	ln -svf $(pwd)/bin/lua-language-server $HOME/.local/bin/lua-language-server

	echo "========================================END"
}

function update_lua() {
	echo "lua=====================================BEGIN"

	LUAVERSION=$(curl -s https://api.github.com/repos/lua/lua/tags | jq -r '.[0].name')
	LUAVERSION="${LUAVERSION:1}"
	echo "updating to lua-$LUAVERSION ..."

	LUAINSTALLHOME=$LIU_ENV/lua
	mkdir -p $LUAINSTALLHOME && cd $LUAINSTALLHOME
	[ -d "$(pwd)/lua" ] && mv $(pwd)/lua $(pwd)/lua$(date +%s)

	wget https://www.lua.org/ftp/lua-$LUAVERSION.tar.gz -q --show-progress
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf lua-$LUAVERSION.tar.gz
	mv lua-$LUAVERSION lua
	rm -rf lua-$LUAVERSION.tar.gz

	cd lua
	make all test
	sudo ln -svf $LUAINSTALLHOME/lua/src/lua $HOME/.local/bin/lua
	sudo ln -svf $LUAINSTALLHOME/lua/src/luac $HOME/.local/bin/luac

	echo "========================================END"
}

function update_luarocks() {
	echo "luarocks================================BEGIN"

	LUAROCKSVERSION=$(curl -s https://api.github.com/repos/luarocks/luarocks/tags | jq -r '.[0].name')
	LUAROCKSVERSION="${LUAROCKSVERSION:1}"
	echo "updating to $LUAROCKSVERSION ..."

	mkdir -p $LIU_ENV/lua && cd $LIU_ENV/lua
	[ -d "$(pwd)/luarocks" ] && mv $(pwd)/luarocks $(pwd)/luarocks$(date +%s)

	wget https://luarocks.org/releases/luarocks-$LUAROCKSVERSION.tar.gz -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	tar zxpf luarocks-$LUAROCKSVERSION.tar.gz
	rm luarocks-$LUAROCKSVERSION.tar.gz
	mv luarocks-$LUAROCKSVERSION luarocks

	cd luarocks
	./configure --with-lua-include=$LIU_ENV/lua/lua/src
	make && sudo make install

	sudo luarocks install luasocket

	echo "========================================END"
}

function update_nodejs() {
	echo "nodejs===================================BEGIN"
	NODEJSVERSION=$(curl -s https://api.github.com/repos/nodejs/node/tags | jq -r '.[0].name')
	NODEJSARCH=x64
	echo "updating to $NODEJSVERSION($NODEJSARCH) ..."

	NODEJSINSTALLHOME=$LIU_ENV/nodejs
	mkdir -p $NODEJSINSTALLHOME && cd $NODEJSINSTALLHOME
	[ -d "$(pwd)/node" ] && mv $(pwd)/node $(pwd)/node$(date +%s)

	wget https://nodejs.org/dist/$NODEJSVERSION/node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz -q --show-progress -P $NODEJSINSTALLHOME
	test $? -eq 1 && echo "fial to download" && return

	xz -d node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz
	tar -xvf node-$NODEJSVERSION-linux-$NODEJSARCH.tar
	mv node-$NODEJSVERSION-linux-$NODEJSARCH node
	rm node-$NODEJSVERSION-linux-$NODEJSARCH.tar

	echo "updating npm..."
	npm install npm@latest -g
	echo "========================================END"
}

function update_ocaml() {
	echo "ocaml==================================BEGIN"
	url="https://api.github.com/repos/ocaml/opam/tags"
	version=$(curl -s $url | jq -r '.[2].name')
	echo "Installing opam-$version..."

	[ -d $LIU_ENV/ocaml ] && mv $LIU_ENV/ocaml $LIU_ENV/ocaml_$(date +%s)
	mkdir -p $LIU_ENV/ocaml
	cd $LIU_ENV/ocaml

	pkg="opam-$version-x86_64-linux"
	wget https://github.com/ocaml/opam/releases/download/$version/opam-$version-x86_64-linux
	test $? -eq 1 && echo "fial to download" && return

	chmod +x $(pwd)/$pkg
	ln -svf $(pwd)/$pkg $HOME/.local/bin/opam
	if [ ! -d $LIU_ENV/ocaml/.opam ]; then
		mkdir $LIU_ENV/ocaml/.opam
		opam init
	fi

	opam install dune ocaml-lsp-server odoc ocamlformat utop
	echo "========================================END"
}

case $1 in
"go")
	update_go
	update_gopls_dlv
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
	update_luarocks
	update_luals
	;;
"nodejs")
	update_nodejs
	;;
"ocaml")
	update_ocaml
	;;
*)
	echo "select one language"
	;;
esac
