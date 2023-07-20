#! /usr/bin/bash
function update_go() {
	echo "========================================BEGIN"

	# get the latest go version
	GOVERSION=$(curl -s 'https://go.dev/dl/?mode=json' | grep '"version"' | sed 1q | awk '{print $2}' | tr -d ',"')
	# get either amd64 or arm64 (darwin/m1)
	GOARCH=$(if [[ $(uname -m) == "x86_64" ]]; then echo amd64; else echo $(uname -m); fi)

	echo "updating to $GOVERSION($GOARCH) ..."

	GOINSTALLHOME=$HOME/env/golang
	mkdir -p $GOINSTALLHOME && cd $GOINSTALLHOME

	[ -d "$(pwd)/go" ] && rm -rf $(pwd)/go

	wget "https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz" -q --show-progress
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz && rm $GOVERSION.linux-$GOARCH.tar.gz

	echo "========================================END"
}

function update_rust() {
	echo "========================================BEGIN"

	if [[ -f "$(which rustup)" ]]; then
		rustup update
	else
		curl https://sh.rustup.rs -sSf | sh
	fi

	rustup component add rust-analyzer rust-src
	ln -svf $(rustup which --toolchain stable rust-analyzer) $CARGO_HOME/bin/rust-analyzer

	echo "========================================END"
}

function update_nodejs() {
	echo "========================================BEGIN"
	NODEJSVERSION=$(curl -s https://api.github.com/repos/nodejs/node/tags | jq -r '.[0].name')
	NODEJSARCH=x64
	echo "updating to $NODEJSVERSION($NODEJSARCH) ..."

	NODEJSINSTALLHOME=$HOME/env/nodejs
	mkdir -p $NODEJSINSTALLHOME && cd $NODEJSINSTALLHOME

	[ -d "$(pwd)/node" ] && rm -rf $(pwd)/node

	wget https://nodejs.org/dist/$NODEJSVERSION/node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz -q --show-progress -P $NODEJSINSTALLHOME
	test $? -eq 1 && echo "fial to download" && return

	xz -d node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz
	tar -xvf node-$NODEJSVERSION-linux-$NODEJSARCH.tar
	rm node-$NODEJSVERSION-linux-$NODEJSARCH.tar
	mv node-$NODEJSVERSION-linux-$NODEJSARCH node

	echo "updating npm..."
	npm install npm@latest -g

	echo "========================================END"
}

function update_lua() {
	echo "========================================BEGIN"
	LUAVERSION=$(curl -s https://api.github.com/repos/lua/lua/tags | jq -r '.[0].name')
	LUAVERSION="${LUAVERSION:1}"

	echo "updating to $LUAVERSION ..."

	LUAINSTALL=$HOME/env/lua
	mkdir -p $LUAINSTALL && cd $LUAINSTALL
	[ -d "$(pwd)/lua" ] && rm -rf $(pwd)/lua

	wget https://www.lua.org/ftp/lua-$LUAVERSION.tar.gz -q --show-progress
	test $? -eq 1 && echo "fial to download lua" && return

	tar -zxvf lua-$LUAVERSION.tar.gz
	mv lua-$LUAVERSION lua
	rm -rf lua-$LUAVERSION.tar.gz

	cd lua
	make all test
	sudo ln -svf $LUAINSTALL/lua/src/lua $HOME/.local/bin/lua
	sudo ln -svf $LUAINSTALL/lua/src/luac $HOME/.local/bin/luac

	echo "========================================END"
}

function update_luarocks() {
	# luarocks
	echo "========================================BEGIN"
	LUAROCKSVERSION=$(curl -s https://api.github.com/repos/luarocks/luarocks/tags | jq -r '.[0].name')
	LUAROCKSVERSION="${LUAROCKSVERSION:1}"

	echo "updating to $LUAROCKSVERSION ..."

	mkdir -p $HOME/env/lua && cd $HOME/env/lua
	[ -d "$(pwd)/luarocks" ] && rm -rf $(pwd)/luarocks

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

case $1 in
"go")
	update_go
	;;
"lua")
	update_lua
	update_luarocks
	;;
"rust")
	update_rust
	;;
"nodejs")
	update_nodejs
	;;
*)
	echo "select one language"
	;;
esac
