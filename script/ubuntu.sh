#!/bin/bash

# PACKAGES
sudo apt update && sudo apt upgrade -y

# cli: editors and text search
sudo apt install -y \
        vim \
        fzf ripgrep

# cli: archives
sudo apt install -y \
        zip unzip

# cli: general utils
sudo apt install -y \
        jq \
        tldr direnv btop cloc

# db: clients
sudo apt install -y \
        sqlite3 \
        redis-tools \
        mysql-client
# mongodb: https://www.mongodb.com/try/download/shell
wget https://downloads.mongodb.com/compass/mongodb-mongosh_2.5.6_amd64.deb | sudo apt install ./mongodb-mongosh_2.5.6_amd64.deb

# dev: version control
sudo apt install -y \
        git git-flow

# dev: build essentials
sudo apt install -y \
        build-essential \
        make cmake ninja-build \
        binutils \
        patchutils \
        graphviz \
        pkg-config # find libs and tell compiler how to link libs

# dev: c and cpp compilers
sudo apt install -y \
        gcc g++

# dev: debugging and indexing
sudo apt install -y \
        clangd \
        gdb lldb-14

# dev: development libraries
sudo apt install -y \
        libncurses5-dev libevent-dev libssl-dev

# lang
# sudo apt install -y python3-pip

# lang: nodejs runtime
# https://deb.nodesource.com/
# curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt install -y nodejs

# net: download and transfer
sudo apt install -y \
        curl wget nghttp2

# net: diagnostics and bridging
sudo apt install -y \
        net-tools bridge-utils

# sys: remote access
sudo apt install -y \
        openssh-server

# sys: shell environment
sudo apt install -y \
        zsh \
        tmux tmuxp

# sys: kernel headers
sudo apt install -y \
        linux-headers-$(uname -r)

# sys: performance tools
sudo apt install -y \
        linux-tools-common linux-tools-generic linux-tools-$(uname -r) \
        sysstat \
        bpfcc-tools

# sys: tracing
sudo apt install -y \
        systemtap-sdt-dev

# sys: containers and sandboxing
sudo apt install -y podman \
        bubblewrap

# # For full system emulation
# sudo apt install -y qemu-system
# # For emulating Linux binaries
# sudo apt install -y qemu-user-static

# sudo apt install -y proxychains4

# sudo apt install -y gh
# sudo apt install -y kitty

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
