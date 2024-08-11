#! /usr/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. $SCRIPT_DIR/helper.sh --source-only

function update_tmux() {
	local tool=tmux
	install_start $tool

	PWD=$(pwd)
	url="https://api.github.com/repos/tmux/tmux/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "Version $version"

	mkdir_tool_dir $tool

	local file=tmux-$version.tar.gz
	github_download $tool $tool $version $file
	test $? -eq 1 && echo "fial to download $tool" && return

	tar -zxvf $file
	cd ./tmux-$version
	./configure
	make && sudo make install

	link_bin $(pwd)/tmux tmux

	cd $PWD
	install_end
}

function update_tpm() {
	install_start tpm

	mkdir -p $XDG_CONFIG_HOME/tmux/plugins/tpm
	git_clone_or_update https://github.com/tmux-plugins/tpm $XDG_CONFIG_HOME/tmux/plugins/tpm

	install_end
}

function nvim_nightly() {
	sudo apt-get install ninja-build gettext cmake unzip curl

	install_start nvim_nightly
	mkdir_tool_dir nvim
	git_clone_or_update https://github.com/neovim/neovim $LIU_TOOLS/nvim
	make CMAKE_BUILD_TYPE=Release
	sudo make install

	install_end
}

function update_marksman() {
	install_start marksman

	url="https://api.github.com/repos/artempyanykh/marksman/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "version $version..."

	mkdir_tool_dir marksman

	local file=marksman-linux-x64
	github_download artempyanykh marksman $version $file
	test $? -eq 1 && echo "fial to download " && return

	chmod +x $(pwd)/$file
	link_bin $(pwd)/marksman-linux-x64 marksman

	install_end
}

function update_mesonlsp() {
	install_start mesonlsp

	url="https://api.github.com/repos/JCWasmx86/mesonlsp/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	echo "version $version..."

	mkdir_tool_dir mesonlsp

	local file=mesonlsp-x86_64-unknown-linux-musl.zip

	github_download JCWasmx86 mesonlsp $version $file
	test $? -eq 1 && echo "fial to download " && return

	unzip $(pwd)/$file
	link_bin $(pwd)/mesonlsp mesonlsp

	install_end
}

function update_fzf() {
	install_start fzf

	mkdir_tool_dir fzf
	git_clone_or_update https://github.com/junegunn/fzf $LIU_TOOLS/fzf
	$LIU_TOOLS/fzf/install

	link_bin $LIU_TOOLS/fzf/bin/fzf fzf

	install_end
}

function update_wrk() {
	install_start wrk

	PWD=$(pwd)

	mkdir wrk
	mkdir_tool_dir wrk
	git_clone_or_update https://github.com/wg/wrk $LIU_TOOLS/wrk

	cd $LIU_TOOLS/wrk
	sudo make

	link_bin $LIU_TOOLS/wrk/wrk wrk

	cd $PWD

	install_end
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
	go install github.com/google/yamlfmt/cmd/yamlfmt@latest

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

	go install github.com/boyter/scc/v3@latest
	go install rsc.io/grepdiff@latest

	# go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

	npm i -g vim-language-server
	npm i -g bash-language-server
	# npm i -g vscode-langservers-extracted # jsonls
	npm i -g vscode-json-languageserver
	npm i -g yaml-language-server
	npm i -g typescript typescript-language-server
	npm i -g pyright

	npm i -g @bufbuild/buf
	npm i -g sql-formatter

	cargo install bat
	cargo install eza
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
	cargo install ast-grep
	cargo install asm-lsp

	cargo install git-absorb # git absorb

	cargo install cargo-nextest
	cargo install cargo-binutils
}

case $1 in
"tmux")
	update_tmux
	update_tpm
	;;
"nvim_nightly")
	nvim_nightly
	;;
"mdls")
	update_marksman
	;;
"mesonlsp")
	update_mesonlsp
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
