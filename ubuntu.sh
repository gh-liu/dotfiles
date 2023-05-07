#!/bin/bash

# PACKAGES
sudo apt update && sudo apt upgrade -y

sudo apt install -y build-essential
sudo apt install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r)

sudo apt install -y sysstat net-tools binutils

sudo apt install -y openssh-server

sudo apt install -y git git-flow gh
sudo apt install -y curl wget
sudo apt install -y zip unzip

sudo apt install -y vim zsh tmux tmuxp
sudo apt install -y bat jq
sudo apt install -y tldr cloc
sudo apt install -y ripgrep silversearcher-ag
sudo apt install -y direnv podman
sudo apt install -y btop

sudo apt install -y lldb-14
sudo apt install -y clangd-12
sudo apt install -y gcc g++ gdb
sudo apt install -y python3-pip

sudo apt install -y make cmake ninja-build

sudo apt install -y sqlite3
sudo apt install -y redis-tools
sudo apt install -y mysql-client

sudo apt install -y proxychains4

# sudo apt install -y libncurses5-dev libevent-dev


# DIRECTORY
mkdir -p $HOME/dev/{golang,rust,nodejs}
mkdir -p $HOME/env/{golang,rust,nodejs}

LIU_TOOLS=$HOME/tools
mkdir -p $LIU_TOOLS


# Dotfiles
git clone https://github.com/gh-liu/dotfiles.git $LIU_TOOLS/dotfiles


# Set zsh as default shell
chsh -s $(which zsh)
# Change the timezone
sudo ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# Set local
sudo locale-gen en_GB en_US en_GB.UTF-8 en_US.UTF-8

# Setup Proxy for APT
# /etc/apt/apt.conf.d/proxy.conf
# Acquire::http::Proxy "http://username:password@proxy-server-ip:8181/";
# Acquire::https::Proxy "https://username:password@proxy-server-ip:8182/";
