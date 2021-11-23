#!/bin/bash

## basic tools
sudo apt update && sudo apt upgrade -y
sudo apt install -y vim zsh tmux tmuxp
sudo apt install -y git ssh
sudo apt install -y python python3-pip
sudo apt install -y graphviz hugo
sudo apt install -y gdb binutils
sudo apt install -y linux-tools-$(uname -r) linux-tools-generic
sudo apt install -y autoconf automake pkg-config
sudo apt install -y ripgrep silversearcher-ag
sudo apt install -y direnv hugo protobuf-compiler apache2-utils tldr ngrep
sudo apt install -y cgroup-tools

### install docker by this (https://docs.docker.com/engine/install/ubuntu/)

## directories
tools=~/tools

mkdir -p $tools
mkdir -p ~/dev/{golang,nodejs}
mkdir -p ~/env/{golang,nodejs}

## proxy
export proxy=http://192.168.102.102:1081
export http_proxy=$proxy
export https_proxy=$proxy

## golang
cd ~/env/golang/

GOVERSION=$(curl -s 'https://golang.org/dl/?mode=json' | grep '"version"' | sed 1q | awk '{print $2}' | tr -d ',"')  # get latest go version
GOARCH=$(if [[ $(uname -m) == "x86_64" ]] ; then echo amd64; else echo $(uname -m); fi) # get either amd64 or arm64 (darwin/m1)

wget https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz

tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz && rm $GOVERSION.linux-$GOARCH.tar.gz

## nodejs
cd ~/env/nodejs/

NODEJSVERSION=v14.18.1
NODEJSARCH=x64

wget https://nodejs.org/dist/$NODEJSVERSION/node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz

xz -d node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz
tar -xvf node-$NODEJSVERSION-linux-$NODEJSARCH.tar && rm node-$NODEJSVERSION-linux-$NODEJSARCH.tar

mv node-$NODEJSVERSION-linux-$NODEJSARCH node

## dotfiles
dotfilespath=$tools/dotfiles
git clone https://github.com/gh-liu/dotfiles.git $dotfilespath
### replace PROXY_HTTP in the .common_func
sed -i "s#PROXY_HTTP=.*#PROXY_HTTP=$proxy#g" $dotfilespath/zsh/.common_func

## oh-my-zsh
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions

## zsh config
mv -v ~/.zshrc ~/.zshrc.old 2> /dev/null
for v in $dotfilespath/zsh/.common_*; do
  ln -svf "$v" ~/
done
ln -svf $dotfilespath/zsh/.zshrc ~/.zshrc
ln -svf $dotfilespath/zsh/7triones.zsh-theme ~/.oh-my-zsh/themes/7triones.zsh-theme

## vim config
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

mv -v ~/.vimrc ~/.vimrc.old 2> /dev/null
for v in $dotfilespath/vim/*.vim; do
  ln -svf "$v" ~/.vim
done
ln -svf $dotfilespath/vim/vimrc ~/.vimrc
ln -svf $dotfilespath/vim/UltiSnips ~/.vim/UltiSnips
ln -svf $dotfilespath/coc/coc-settings.json ~/.vim/coc-settings.json

## tmux
mkdir -p ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

mv -v ~/.tmux.conf ~/.tmux.conf.old 2> /dev/null
ln -svf $dotfilespath/tmux/tmux.conf ~/.tmux.conf

## autojump
git clone git://github.com/wting/autojump.git $tools/autojump
cd $tools/autojump
./install.py

## ctags
git clone https://github.com/universal-ctags/ctags.git $tools/ctags
cd $tools/ctags
./autogen.sh
./configure  # --prefix=/where/you/want defaults to /usr/local
make
sudo make install

source ~/.zshrc
vim +PlugInstall +qall

## protobuf go
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

## wrk
cd $tools
# sudo apt-get install build-essential libssl-dev git -y 
git clone https://github.com/wg/wrk.git wrk 
cd wrk 
sudo make 
sudo cp wrk /usr/local/bin 
