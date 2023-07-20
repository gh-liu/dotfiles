#! /usr/bin/bash
function git_clone_or_update() {
	git clone "$1" "$2" 2>/dev/null && echo 'Update status: Success' || (
		cd "$2"
		git pull
	)
}

function update_luals() {
	echo "========================================"
	url="https://api.github.com/repos/LuaLS/lua-language-server/tags"
	version=$(eval "curl -s $url | jq -r '.[0].name'")
	echo "Installing luals-$version..."

	[ -d $HOME/tools/luals ] && rm -rf $HOME/tools/luals
	mkdir -p $HOME/tools/luals
	cd $HOME/tools/luals

	pkg="lua-language-server-$version-linux-x64.tar.gz"
	wget https://github.com/LuaLS/lua-language-server/releases/download/$version/$pkg -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf ./$pkg
	ln -svf $(pwd)/bin/lua-language-server $HOME/.local/bin/lua-language-server

	echo "========================================"
}

function update_fzf() {
	echo "========================================"
	echo "Installing fzf..."

	git_clone_or_update https://github.com/junegunn/fzf.git $LIU_TOOLS/fzf
	$LIU_TOOLS/fzf/install

	mkdir -p $HOME/.local/bin
	ln -svf $LIU_TOOLS/fzf/bin/fzf $HOME/.local/bin/fzf

	echo "========================================"
}

function update_wrk() {
	PWD=$(pwd)

	echo "========================================"
	echo "Installing wrk..."

	git_clone_or_update https://github.com/wg/wrk.git $LIU_TOOLS/wrk

	cd $LIU_TOOLS/wrk
	sudo make

	mkdir -p $HOME/.local/bin
	ln -svf $LIU_TOOLS/wrk/wrk $HOME/.local/bin/wrk

	echo "========================================"

	cd $PWD
}

function update_tmux() {
	PWD=$(pwd)

	echo "========================================"
	echo "Installing tmux..."

	mkdir -p $XDG_CONFIG_HOME/tmux/plugins/tpm
	git_clone_or_update https://github.com/tmux-plugins/tpm $XDG_CONFIG_HOME/tmux/plugins/tpm

	mkdir $LIU_TOOLS/tmux && cd $LIU_TOOLS/tmux
	wget https://github.com/tmux/tmux/releases/download/3.3a/tmux-3.3a.tar.gz
	test $? -eq 1 && echo "fial to download tmux" && return

	tar -zxvf ./tmux-3.3a.tar.gz
	cd ./tmux-3.3a
	./configure
	make && sudo make install

	mkdir -p $HOME/.local/bin
	ln -svf $(pwd)/tmux $HOME/.local/bin/tmux
	echo "========================================"

	cd $PWD
}

bins() {
	export GOPROXY=https://goproxy.io
	if [[ $OS == linux ]]; then
		go install golang.org/x/tools/gopls@latest
		go install github.com/go-delve/delve/cmd/dlv@latest
	fi
	go install mvdan.cc/gofumpt@latest
	go install github.com/josharian/impl@latest
	go install github.com/fatih/gomodifytags@latest
	go install mvdan.cc/sh/v3/cmd/shfmt@latest
	go install github.com/gohugoio/hugo@latest
	go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

	npm i -g vim-language-server
	npm i -g bash-language-server
	npm i -g yaml-language-server
	npm i -g vscode-langservers-extracted

	cargo install fd
	cargo install bat
	cargo install exa
	cargo install just
	cargo install zoxide
	cargo install ripgrep
	cargo install stylua
}

case $1 in
"luals")
	update_luals
	;;
"tmux")
	update_tmux
	;;
"wrk")
	update_wrk
	;;
"fzf")
	update_fzf
	;;
*)
	bins
	;;
esac
