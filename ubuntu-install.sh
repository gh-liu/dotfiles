#!/bin/bash

## basic tools
sudo apt update && sudo apt upgrade -y
sudo apt install -y git ssh
sudo apt install -y vim zsh tmux tmuxp
sudo apt install -y autoconf automake pkg-config 
sudo apt install -y linux-tools-$(uname -r) linux-tools-generic
sudo apt install -y gdb binutils cgroup-tools
sudo apt install -y ripgrep silversearcher-ag fd-find
sudo apt install -y apache2-utils ngrep
sudo apt install -y python python3-pip
sudo apt install -y libsqlite3-dev
sudo apt install -y hugo tldr direnv graphviz protobuf-compiler
sudo apt install -y pax-utils elfutils prelink
# sudo apt install -y ttf-mscorefonts-installer
sudo apt install -y xsel

### install docker(https://docs.docker.com/engine/install/ubuntu/)
### intsall docker-compose(https://docs.docker.com/compose/install/)

### install stylua(https://github.com/JohnnyMorganz/StyLua)

## install

sh -c "$(wget -O- https://raw.githubusercontent.com/gh-liu/dotfiles/master/install.sh)"
