### lua
update_lua () {
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

### luarocks
update_luarocks () {
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