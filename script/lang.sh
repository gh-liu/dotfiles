#! /usr/bin/bash
function update_go() {
	echo "========================================BEGIN"
	echo "go..........................................."
	GOVERSION=$(curl -s "https://go.dev/dl/?mode=json" | jq -r '.[0]."files" | .[0].version')
	GOARCH=$(if [[ $(uname -m) == "x86_64" ]]; then echo amd64; else echo $(uname -m); fi)
	echo "updating to $GOVERSION($GOARCH) ..."

	GOINSTALLHOME=$HOME/env/golang
	mkdir -p $GOINSTALLHOME && cd $GOINSTALLHOME
	[ -d "$(pwd)/go" ] && mv $(pwd)/go $(pwd)/go$(date +%s)

	wget "https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz" -q --show-progress
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz && rm $GOVERSION.linux-$GOARCH.tar.gz
	echo "========================================END"
}

function update_zig() {
	echo "========================================BEGIN"
	echo "zig.........................................."
	VERSION=$(curl -s https://ziglang.org/download/index.json | jq -r '.master."version"')
	echo "updating to $VERSION ..."

	ZIGINSTALLHOME=$HOME/env/zig
	mkdir -p $ZIGINSTALLHOME && cd $ZIGINSTALLHOME
	[ -d "$(pwd)/zig" ] && mv $(pwd)/zig $(pwd)/zig$(date +%s)

	wget $(curl -s https://ziglang.org/download/index.json | jq -r '.master."x86_64-linux".tarball') -q --show-progress
	test $? -eq 1 && echo "fial to download" && return
	tar xvJf zig-linux-x86_64-$VERSION.tar.xz
	rm zig-linux-x86_64-$VERSION.tar.xz
	mv zig-linux-x86_64-$VERSION zig

	sudo ln -svf $(pwd)/zig/zig /usr/bin/zig

	echo "zls.........................................."
	ZLSINSTALLHOME=$HOME/env/zig/zls
	if [ -d $ZLSINSTALLHOME ]; then
		cd $ZLSINSTALLHOME
		git pull
	else
		mkdir -p $ZLSINSTALLHOME && cd $ZLSINSTALLHOME
		git clone https://github.com/zigtools/zls .
	fi
	zig build -Doptimize=ReleaseSafe
	chmod +x $(pwd)/zig-out/bin/zls
	sudo ln -svf $(pwd)/zig-out/bin/zls /usr/bin/zls

	echo "========================================END"
}

function update_ocaml() {
	echo "========================================BEGIN"
	url="https://api.github.com/repos/ocaml/opam/tags"
	version=$(curl -s $url | jq -r '.[2].name')
	echo "Installing opam-$version..."

	[ -d $HOME/env/ocaml ] && mv $HOME/env/ocaml $HOME/env/ocaml_$(date +%s)
	mkdir -p $HOME/env/ocaml
	cd $HOME/env/ocaml

	pkg="opam-$version-x86_64-linux"
	wget https://github.com/ocaml/opam/releases/download/$version/opam-$version-x86_64-linux
	test $? -eq 1 && echo "fial to download" && return

	chmod +x $(pwd)/$pkg
	ln -svf $(pwd)/$pkg $HOME/.local/bin/opam
	if [ ! -d $HOME/env/ocaml/.opam ]; then
		mkdir $HOME/env/ocaml/.opam
		opam init
	fi

	opam install dune ocaml-lsp-server odoc ocamlformat utop
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

function update_nodejs() {
	echo "========================================BEGIN"
	echo "nodejs......................................."
	NODEJSVERSION=$(curl -s https://api.github.com/repos/nodejs/node/tags | jq -r '.[0].name')
	NODEJSARCH=x64
	echo "updating to $NODEJSVERSION($NODEJSARCH) ..."

	NODEJSINSTALLHOME=$HOME/env/nodejs
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

function update_lua() {
	echo "========================================BEGIN"
	echo "lua.........................................."
	LUAVERSION=$(curl -s https://api.github.com/repos/lua/lua/tags | jq -r '.[0].name')
	LUAVERSION="${LUAVERSION:1}"
	echo "updating to $LUAVERSION ..."

	LUAINSTALLHOME=$HOME/env/lua
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
	echo "========================================BEGIN"
	echo "luarocks....................................."
	LUAROCKSVERSION=$(curl -s https://api.github.com/repos/luarocks/luarocks/tags | jq -r '.[0].name')
	LUAROCKSVERSION="${LUAROCKSVERSION:1}"
	echo "updating to $LUAROCKSVERSION ..."

	mkdir -p $HOME/env/lua && cd $HOME/env/lua
	[ -d "$(pwd)/luarocks" ] && mv $(pwd)/luarocks $(pwd)/luarocks$(date +%s)

	wget https://luarocks.org/releases/luarocks-$LUAROCKSVERSION.tar.gz -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	tar zxpf luarocks-$LUAROCKSVERSION.tar.gz
	rm luarocks-$LUAROCKSVERSION.tar.gz
	mv luarocks-$LUAROCKSVERSION luarocks

	cd luarocks
	./configure --with-lua-include=$HOME/env/lua/lua/src
	make && sudo make install

	sudo luarocks install luasocket
	echo "========================================END"
}

function update_fennel() {
	echo "========================================BEGIN"
	echo "fennel......................................."
	sudo luarocks install fennel
	echo "========================================END"
}

case $1 in
"go")
	update_go
	;;
"lua")
	update_lua
	update_luarocks
	update_fennel
	;;
"rust")
	update_rust
	;;
"zig")
	update_zig
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
