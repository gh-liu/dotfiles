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

## install

sh -c "$(wget -O- https://raw.githubusercontent.com/gh-liu/dotfiles/master/install.sh)"
