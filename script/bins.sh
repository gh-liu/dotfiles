#! /usr/bin/bash
function git_clone_or_update() {
	git clone "$1" "$2" 2>/dev/null && echo 'Update status: Success' || (
		cd "$2"
		git pull
	)
}

function update_luals() {
	echo "========================================BEGIN"
	url="https://api.github.com/repos/LuaLS/lua-language-server/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "Installing luals-$version..."

	[ -d $HOME/tools/luals ] && mv $HOME/tools/luals $HOME/tools/luals$(date +%s)
	mkdir -p $HOME/tools/luals
	cd $HOME/tools/luals

	pkg="lua-language-server-$version-linux-x64.tar.gz"
	wget https://github.com/LuaLS/lua-language-server/releases/download/$version/$pkg -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf ./$pkg
	ln -svf $(pwd)/bin/lua-language-server $HOME/.local/bin/lua-language-server
	echo "========================================END"
}

function update_marksman() {
	echo "========================================BEGIN"
	url="https://api.github.com/repos/artempyanykh/marksman/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "Installing marksman-$version..."

	[ -d $HOME/tools/marksman ] && mv $HOME/tools/marksman $HOME/tools/marksman$(date +%s)
	mkdir -p $HOME/tools/marksman
	cd $HOME/tools/marksman

	wget https://github.com/artempyanykh/marksman/releases/download/$version/marksman-linux-x64 -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	chmod +x $(pwd)/marksman-linux-x64
	ln -svf $(pwd)/marksman-linux-x64 $HOME/.local/bin/marksman
	echo "========================================END"
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
	echo "========================================"
	PWD=$(pwd)
	echo "Installing wrk..."

	git_clone_or_update https://github.com/wg/wrk.git $LIU_TOOLS/wrk

	cd $LIU_TOOLS/wrk
	sudo make

	mkdir -p $HOME/.local/bin
	ln -svf $LIU_TOOLS/wrk/wrk $HOME/.local/bin/wrk

	cd $PWD
	echo "========================================"
}

function update_tmux() {
	echo "========================================"
	PWD=$(pwd)

	url="https://api.github.com/repos/LuaLS/lua-language-server/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "Installing tmux-$version..."

	mkdir $LIU_TOOLS/tmux && cd $LIU_TOOLS/tmux
	wget https://github.com/tmux/tmux/releases/download/$version/tmux-$version.tar.gz
	test $? -eq 1 && echo "fial to download tmux" && return

	tar -zxvf ./tmux-3.3a.tar.gz
	cd ./tmux-3.3a
	./configure
	make && sudo make install

	mkdir -p $HOME/.local/bin
	ln -svf $(pwd)/tmux $HOME/.local/bin/tmux

	# mkdir -p $XDG_CONFIG_HOME/tmux/plugins/tpm
	# git_clone_or_update https://github.com/tmux-plugins/tpm $XDG_CONFIG_HOME/tmux/plugins/tpm

	cd $PWD
	echo "========================================"
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
	go install golang.org/x/tools/cmd/goimports@latest

	go install github.com/bufbuild/buf-language-server/cmd/bufls@latest
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

	go install mvdan.cc/sh/v3/cmd/shfmt@latest
	go install github.com/gohugoio/hugo@latest
	go install github.com/charmbracelet/glow@latest
	go install github.com/abhinav/tmux-fastcopy@latest

	# go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

	npm i -g vim-language-server
	npm i -g bash-language-server
	npm i -g vscode-langservers-extracted # jsonls
	npm i -g yaml-language-server
	npm i -g typescript typescript-language-server
	npm i -g pyright

	npm i -g @bufbuild/buf

	cargo install bat
	cargo install exa
	cargo install just
	cargo install stylua
	cargo install zoxide
	cargo install ripgrep
	cargo install fd-find
	cargo install tealdeer
	cargo install git-delta
	cargo install starship --locked
}

function update_protobuf() {
	echo "========================================BEGIN"
	url="https://api.github.com/repos/protocolbuffers/protobuf/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	version="${version:1}"
	echo "Installing protobuf-$version..."

	[ -d $HOME/tools/protobuf ] && mv $HOME/tools/protobuf $HOME/tools/protobuf$(date +%s)
	mkdir -p $HOME/tools/protobuf
	cd $HOME/tools/protobuf

	pkg="protoc-$version-linux-x86_64.zip"
	wget https://github.com/protocolbuffers/protobuf/releases/download/v$version/$pkg -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	unzip ./$pkg
	ln -svf $(pwd)/bin/protoc $HOME/.local/bin/protoc
	echo "========================================END"
}

case $1 in
"luals")
	update_luals
	;;
"mdls")
	update_marksman
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
