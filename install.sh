#!/bin/bash

## directories

tools=~/tools

mkdir -p $tools
mkdir -p ~/dev/{golang,nodejs,python3,lua}
mkdir -p ~/env/{golang,nodejs,python3,lua}

## proxy

export PROXY_HTTP=http://192.168.102.102:1081 # Todo: need set by youself
export http_proxy=$proxy
export https_proxy=$proxy

## dev env 

### golang

cd ~/env/golang/

GOVERSION=$(curl -s 'https://golang.org/dl/?mode=json' | grep '"version"' | sed 1q | awk '{print $2}' | tr -d ',"')  # get latest go version
GOARCH=$(if [[ $(uname -m) == "x86_64" ]] ; then echo amd64; else echo $(uname -m); fi) # get either amd64 or arm64 (darwin/m1)

wget https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz

tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz && rm $GOVERSION.linux-$GOARCH.tar.gz

### nodejs

cd ~/env/nodejs/

NODEJSVERSION=v14.18.1 # Todo: auto get the version
NODEJSARCH=x64 # Todo: auto get the arch

wget https://nodejs.org/dist/$NODEJSVERSION/node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz

xz -d node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz
tar -xvf node-$NODEJSVERSION-linux-$NODEJSARCH.tar && rm node-$NODEJSVERSION-linux-$NODEJSARCH.tar

mv node-$NODEJSVERSION-linux-$NODEJSARCH node

### lua
cd ~/env/lua/

LUAVERSION=5.4.3

wget https://www.lua.org/ftp/lua-$LUAVERSION.tar.gz
tar -zxvf lua-$LUAVERSION.tar.gz

mv lua-$LUAVERSION lua
cd ~/env/lua/lua
make all test

sudo ln -svf ~/env/lua/lua/src/lua /usr/bin/lua

### python3
<<COMMENT
cd ~/env/python3/

PYVERSION=3.9.9
wget https://www.python.org/ftp/python/$PYVERSION/Python-$PYVERSION.tar.xz

xz -d Python-$PYVERSION.tar.xz
tar -xvf Python-$PYVERSION.tar && rm Python-$PYVERSION.tar
COMMENT

## dotfiles

dotfilespath=$tools/dotfiles

git clone https://github.com/gh-liu/dotfiles.git $dotfilespath

<<COMMENT
replace PROXY_HTTP in the .common_func
COMMENT

sed -i "s#PROXY_HTTP=.*#PROXY_HTTP=$proxy#g" $dotfilespath/zsh/zsh.conf/func

### tmux

#### tpm

mkdir -p ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

#### config

mv -v ~/.tmux.conf ~/.tmux.conf.old 2> /dev/null
ln -svf $(pwd)/tmux/tmux.conf ~/.tmux.conf

### zsh

#### ohmyzsh and plugin

git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
<<COMMENT
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
COMMENT

#### config

mv -v ~/.zshrc ~/.zshrc.old 2> /dev/null
ln -svf $(pwd)/zsh/zsh.conf ~/zsh.conf
ln -svf $(pwd)/zsh/.zshrc ~/.zshrc
ln -svf $(pwd)/zsh/7triones.zsh-theme ~/.oh-my-zsh/themes/7triones.zsh-theme
source ~/.zshrc

### vim

#### config
mv -v ~/.vimrc ~/.vimrc.old 2> /dev/null
ln -svf $(pwd)/vim/vimrc ~/.vimrc
ln -svf $(pwd)/vim/dotvim ~/.vim
<<COMMENT
Make sure that the vim-plug have installed.
COMMENT
vim +PlugInstall +qall

### nvim

mkdir -p ~/.config
ln -svf $(pwd)/nvim ~/.config/nvim

### alacritty

ln -svf $(pwd)/alacritty/alacritty.yml ~/.alacritty.yml

## utils

### ctags

git clone https://github.com/universal-ctags/ctags.git $tools/ctags
cd $tools/ctags
./autogen.sh
./configure  # --prefix=/where/you/want defaults to /usr/local
make
sudo make install

### autojump

git clone git://github.com/wting/autojump.git $tools/autojump
cd $tools/autojump
./install.py

### tmuxp

pip install --user tmuxp

### wrk

cd $tools
<<COMMENT
some dependencies:
sudo apt-get install build-essential libssl-dev git -y
COMMENT
git clone https://github.com/wg/wrk.git wrk 
cd wrk 
sudo make 
sudo cp wrk /usr/local/bin 

### protobuf go

go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
