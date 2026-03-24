#!/bin/bash

# PACKAGES
sudo apt update && sudo apt upgrade -y

# shell and editors
sudo apt install -y \
        vim zsh tmux tmuxp \
        openssh-server

# archives and transfer
sudo apt install -y \
        zip unzip \
        curl wget nghttp2

# search and cli utils
sudo apt install -y \
        fzf ripgrep \
        jq \
        bubblewrap \
        tldr direnv btop cloc

# version control
sudo apt install -y \
        git git-flow

# build essentials
sudo apt install -y \
        build-essential \
        make cmake ninja-build \
        binutils \
        patchutils \
        graphviz

# c and cpp toolchain
sudo apt install -y \
        gcc g++ \
        clangd \
        gdb lldb-14

# development libraries
sudo apt install -y \
        libncurses5-dev libevent-dev

# kernel headers and perf tools
sudo apt install -y \
        linux-tools-common linux-tools-generic linux-tools-$(uname -r) \
        linux-headers-$(uname -r)

# system network and metrics
sudo apt install -y \
        sysstat net-tools bridge-utils \
        bpfcc-tools

# tracing
sudo apt install -y \
        systemtap-sdt-dev

# sudo apt install -y gh
# sudo apt install -y kitty

# databases
sudo apt install -y \
        sqlite3 \
        redis-tools \
        mysql-client

# mongodb: https://www.mongodb.com/try/download/shell
wget https://downloads.mongodb.com/compass/mongodb-mongosh_2.5.6_amd64.deb | sudo apt install ./mongodb-mongosh_2.5.6_amd64.deb

# lang
# sudo apt install -y python3-pip

# nodejs
# https://deb.nodesource.com/
# curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt install -y nodejs

# containers
sudo apt install -y podman

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
