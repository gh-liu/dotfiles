#!/bin/bash

# PACKAGES
sudo apt update && sudo apt upgrade -y

sudo apt install -y openssh-server

sudo apt install -y build-essential
sudo apt install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r)

sudo apt install -y sysstat net-tools bridge-utils
sudo apt install -y binutils

sudo apt install -y patchutils # grepdiff

sudo apt install -y git git-flow
sudo apt install -y gh
sudo apt install -y kitty

sudo apt install -y curl wget nghttp2
sudo apt install -y zip unzip

sudo apt install -y vim zsh tmux tmuxp
sudo apt install -y tldr direnv podman btop cloc jq
sudo apt install -y fzf ripgrep silversearcher-ag

sudo apt install -y gcc g++
sudo apt install -y clangd
sudo apt install -y gdb lldb-14

sudo apt install -y bpfcc-tools linux-headers-$(uname -r)
# dtrace
sudo apt-get install systemtap-sdt-dev

# build
sudo apt install -y make cmake ninja-build
sudo apt install -y graphviz

# databases
sudo apt install -y sqlite3
sudo apt install -y redis-tools
sudo apt install -y mysql-client

# lang
# sudo apt install -y python3-pip

# nodejs
# https://deb.nodesource.com/
# curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt install -y nodejs

# libs
sudo apt install -y libncurses5-dev libevent-dev

# # For full system emulation
# sudo apt install -y qemu-system
# # For emulating Linux binaries
# sudo apt install -y qemu-user-static

# sudo apt install -y proxychains4

# DIRECTORY
mkdir -p $HOME/env/{golang,rust,zig,lua,nodejs}
mkdir -p $HOME/dev

mkdir -p $HOME/.local/bin

LIU_TOOLS=$HOME/tools
mkdir -p $LIU_TOOLS

# Dotfiles
git clone https://github.com/gh-liu/dotfiles.git $LIU_TOOLS/dotfiles

# Change the timezone
sudo ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# Set local
sudo locale-gen en_GB en_US en_GB.UTF-8 en_US.UTF-8

# Set zsh as default shell
chsh -s $(which zsh)

# Setup Proxy for APT
# /etc/apt/apt.conf.d/proxy.conf
# Acquire::http::Proxy "http://username:password@proxy-server-ip:8181/";
# Acquire::https::Proxy "https://username:password@proxy-server-ip:8182/";
