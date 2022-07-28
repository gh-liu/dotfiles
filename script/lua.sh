#! /usr/bin/bash
function update_lua() {
	cd $HOME/env/lua/
	LUAVERSION=5.4.3

	wget https://www.lua.org/ftp/lua-$LUAVERSION.tar.gz
	tar -zxvf lua-$LUAVERSION.tar.gz

	mv lua-$LUAVERSION lua
	cd $HOME/env/lua/lua
	make all test

	sudo ln -svf $HOME/env/lua/lua/src/lua /usr/bin/lua
	sudo ln -svf $HOME/env/lua/lua/src/luac /usr/bin/luac
}

function update_luarocks() {
	cd $HOME/env/lua
	LUAROCKSVERSION=3.8.0
	wget https://luarocks.org/releases/luarocks-3.8.0.tar.gz
	tar zxpf luarocks-3.8.0.tar.gz
	mv luarocks-$LUAROCKSVERSION luarocks
	cd luarocks

	./configure --with-lua-include=$HOME/env/lua/lua/src
	make
	sudo make install
}

function update_stylua() {
	cd $HOME/tools/stylua
	wget https://github.com/JohnnyMorganz/StyLua/releases/download/v0.13.1/stylua-linux.zip
	unzip stylua-linux.zip && rm stylua-linux.zip
	chmod +x $(pwd)/stylua
	mkdir -p $HOME/bin
	ln -svf $(pwd)/stylua $HOME/bin/stylua
}

function update_sumneko() {
	sudo apt install -y ninja-build
	# clone project
	mkdir -p $HOME/tools/sumneko_lua && cd $HOME/tools/sumneko_lua
	git clone --depth=1 https://github.com/sumneko/lua-language-server
	cd lua-language-server
	git submodule update --depth 1 --init --recursive

	cd 3rd/luamake
	./compile/install.sh
	cd ../..
	./3rd/luamake/luamake rebuild

	mkdir -p $HOME/bin
	ln -svf $(pwd)/bin/lua-language-server $HOME/bin/lua-language-server
}
