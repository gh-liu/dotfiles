#! /usr/bin/bash
function git_clone_or_update() {
	git clone "$1" "$2" 2>/dev/null && echo 'Update status: Success' || (
		cd "$2"
		git pull
	)
}

function update_tmux() {
	# echo "========================================"
	# PWD=$(pwd)

	# url="https://api.github.com/repos/tmux/tmux/tags"
	# version=$(curl -s $url | jq -r '.[0].name')
	# echo "Installing tmux-$version..."

	# mkdir $LIU_TOOLS/tmux && cd $LIU_TOOLS/tmux
	# wget https://github.com/tmux/tmux/releases/download/$version/tmux-$version.tar.gz
	# test $? -eq 1 && echo "fial to download tmux" && return

	# tar -zxvf ./tmux-$version.tar.gz
	# cd ./tmux-$version
	# ./configure
	# make && sudo make install

	# mkdir -p $HOME/.local/bin
	# ln -svf $(pwd)/tmux $HOME/.local/bin/tmux

	# cd $PWD
	# echo "========================================"

	echo "========================================"
	echo "Installing tpm..."
	mkdir -p $XDG_CONFIG_HOME/tmux/plugins/tpm
	git_clone_or_update https://github.com/tmux-plugins/tpm $XDG_CONFIG_HOME/tmux/plugins/tpm
	echo "========================================"
}

function nvim_nightly() {
	sudo apt-get install ninja-build gettext cmake unzip curl
	echo "========================================BEGIN"
	mkdir -p $LIU_TOOLS/nvim
	git_clone_or_update https://github.com/neovim/neovim $LIU_TOOLS/nvim
	cd $LIU_TOOLS/nvim
	make CMAKE_BUILD_TYPE=Release
	sudo make install
	echo "========================================END"
}

function update_marksman() {
	echo "========================================BEGIN"
	url="https://api.github.com/repos/artempyanykh/marksman/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "Installing marksman-$version..."

	[ -d $LIU_TOOLS/marksman ] && mv $LIU_TOOLS/marksman $LIU_TOOLS/marksman$(date +%s)
	mkdir -p $LIU_TOOLS/marksman
	cd $LIU_TOOLS/marksman

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

bins() {
	export GOPROXY=https://goproxy.io
	if [[ $OS == linux ]]; then
		local GOPLSVERSION=$(curl -s https://api.github.com/repos/golang/tools/releases | jq -r ".[0].tag_name" | cut -d/ -f2)
		go install golang.org/x/tools/gopls@$GOPLSVERSION
		# go install golang.org/x/tools/gopls@latest

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

	go install github.com/jesseduffield/lazygit@latest
	go install github.com/jesseduffield/lazydocker@latest

	go install honnef.co/go/gotraceui/cmd/gotraceui@latest

	# go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

	npm i -g vim-language-server
	npm i -g bash-language-server
	npm i -g vscode-langservers-extracted # jsonls
	npm i -g yaml-language-server
	npm i -g typescript typescript-language-server
	npm i -g pyright

	npm i -g @bufbuild/buf
	npm i -g sql-formatter

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
	cargo install inferno # flamegraph
	cargo install --features lsp --locked taplo-cli

	cargo install git-absorb # git absorb

	cargo install cargo-nextest
	cargo install cargo-binutils
}

function update_protobuf() {
	echo "========================================BEGIN"
	url="https://api.github.com/repos/protocolbuffers/protobuf/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	version="${version:1}"
	echo "Installing protobuf-$version..."

	[ -d $LIU_TOOLS/protobuf ] && mv $LIU_TOOLS/protobuf $LIU_TOOLS/protobuf$(date +%s)
	mkdir -p $LIU_TOOLS/protobuf
	cd $LIU_TOOLS/protobuf

	pkg="protoc-$version-linux-x86_64.zip"
	wget https://github.com/protocolbuffers/protobuf/releases/download/v$version/$pkg -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	unzip ./$pkg
	ln -svf $(pwd)/bin/protoc $HOME/.local/bin/protoc
	echo "========================================END"
}

# Install Docker Engine on Ubuntu
install_docker() {
	for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

	sudo apt-get update
	sudo apt-get install ca-certificates curl gnupg
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut --delimiter="=" --fields=2)
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo apt-get update

	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	sudo docker run hello-world
}

case $1 in
"tmux")
	update_tmux
	;;
"nvim_nightly")
	nvim_nightly
	;;
"mdls")
	update_marksman
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
