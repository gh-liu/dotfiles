#!/bin/bash

## basic tools
sudo apt update && sudo apt upgrade -y
sudo apt install -y vim zsh tmux
sudo apt install -y git ssh docker.io
sudo apt install -y nodejs npm
sudo apt install -y graphviz hugo
sudo apt install -y linux-tools-$(uname -r) linux-tools-generic

## directories
mkdir -p ~/tools
mkdir -p ~/dev/{golang,nodejs}
mkdir -p ~/env/{golang,nodejs}

## proxy

## golang
cd ~/env/golang/

GOVERSION=$(curl -s 'https://golang.org/dl/?mode=json' | grep '"version"' | sed 1q | awk '{print $2}' | tr -d ',"')  # get latest go version
GOARCH=$(if [[ $(uname -m) == "x86_64" ]] ; then echo amd64; else echo $(uname -m); fi) # get either amd64 or arm64 (darwin/m1)

wget https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz

tar xvf $GOVERSION.linux-$GOARCH.tar.gz && rm $GOVERSION.linux-$GOARCH.tar.gz

## dotfiles
cd ~/tools
git clone https://github.com/gh-liu/dotfiles.git

## oh-my-zsh
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

## vim config

## tmux config