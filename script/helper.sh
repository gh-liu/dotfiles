#! /usr/bin/bash

function git_clone_or_update() {
	git clone "$1" "$2" 2>/dev/null && echo 'Update status: Success' || (
		cd "$2"
		git pull
	)
}

function install_start() {
	echo "========================================"
	echo "Installing $1..."
}

function install_end() {
	echo "========================================"
}

function github_download() {
	user=$1
	repo=$2
	version=$3
	release=$4
	wget https://github.com/$user/$repo/releases/download/$version/$release -q --show-progres
}

function mkdir_tool_dir() {
	mkdir -p $LIU_TOOLS/$1 && cd $LIU_TOOLS/$1
}

function mkdir_env_dir() {
	mkdir -p $LIU_ENV/$1 && cd $LIU_ENV/$1
}

function backup() {
	[ -d $(pwd)/$1 ] && mv $(pwd)/$1 $(pwd)/$1$(date +%s)
}

function link_bin() {
	mkdir -p $HOME/.local/bin
	ln -svf $1 $HOME/.local/bin/$2
}
