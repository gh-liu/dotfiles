#! /bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. $SCRIPT_DIR/helper.sh --source-only

function update_protobuf() {
	local tool=protobuf
	install_start $tool
	url="https://api.github.com/repos/protocolbuffers/protobuf/tags"
	version=$(curl -s $url | jq -r '.[0].name')
	vv=$(echo $version | sed "s/^v//")
	pkg=protoc-$vv-linux-x86_64.zip
	mkdir_tool_dir $tool
	curl -LO https://github.com/protocolbuffers/protobuf/releases/download/$version/$pkg
	unzip $pkg
	link_bin $LIU_TOOLS/$tool/bin/protoc $tool
	install_end
}

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
	[[ $? -ne 0 ]] && echo "fail to download $tool" >&2 && return 1

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
	# NOTE: ubuntu
	sudo apt-get install ninja-build gettext cmake unzip curl

	install_start nvim_nightly
	mkdir_tool_dir nvim
	git_clone_or_update https://github.com/neovim/neovim $LIU_TOOLS/nvim
	make CMAKE_BUILD_TYPE=Release
	sudo make install

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

bins() {
	if [ -f "$(which go)" ]; then
		export GOPROXY=https://goproxy.io
		if [[ $OS == linux ]]; then
			local GOPLSVERSION=$(curl -s https://api.github.com/repos/golang/tools/releases | jq -r ".[0].tag_name" | cut -d/ -f2)
			go install golang.org/x/tools/gopls@$GOPLSVERSION
			# go install golang.org/x/tools/gopls@latest
			go install github.com/go-delve/delve/cmd/dlv@latest
		fi

		# go install honnef.co/go/gotraceui/cmd/gotraceui@latest

		go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
		go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

		go install rsc.io/grepdiff@latest
		go install github.com/rakyll/hey@latest
		go install github.com/boyter/scc/v3@latest

		go install github.com/jesseduffield/lazygit@latest
		go install github.com/jesseduffield/lazydocker@latest

		go install golang.org/x/tools/cmd/present@latest
		go install github.com/abhinav/tmux-fastcopy@latest
		go install github.com/charmbracelet/glow/v2@latest # markdown preview

		# go install github.com/gohugoio/hugo@latest
		CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest

		go install -ldflags "-s -w" github.com/tristanisham/zvm@latest
		# go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
		go install github.com/kopecmaciej/vi-mongo@latest

		go install github.com/sinclairtarget/git-who@latest
		go install github.com/superfly/flyctl@latest
	fi

	if [ -f "$(which bun)" ]; then
		bun i -g @biomejs/biome

		bun i -g @bufbuild/buf
		bun i -g sql-formatter

		# bun i -g tree-sitter-cli
	fi

	if [ -f "$(which uv)" ]; then
		uv tool install --force jupyterlab
		uv tool install --force notebook

		uv tool install --force pre-commit
		uv tool install --force git-filter-repo

		uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

		uv tool install sqlit-tui # tui for sql databases
		uv tool install mitmproxy
	fi

	if [ -f "$(which cargo)" ]; then
		# NOTE: use `cargo binstall` to install bins
		cargo install cargo-binstall

		cargo install bat
		cargo install eza
		cargo install zoxide
		cargo install tealdeer
		cargo install git-delta difftastic
		cargo install starship --locked
		cargo install inferno # flamegraph
		cargo install asm-lsp
		cargo install skim
		cargo install --locked zellij

		cargo install cargo-nextest
		cargo install cargo-binutils

		cargo install hyperfine # command-line benchmarking

		cargo install tree-sitter-cli

		cargo install shpool

		cargo install --locked --bin jj jj-cli
		cargo install worktrunk

	fi

	if [ -f "$(which gh)" ]; then
		gh extension install yusukebe/gh-markdown-preview
	fi

	if [[ $OS == linux ]]; then
		# if [ -f "$(which kubectl)" ]; then
		# 	curl -o ~/.local/bin/minikube -L https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
		#
		# 	# NOTE: kubeadm
		# 	# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm
		#
		# 	# https://v1-32.docs.kubernetes.io/docs/tasks/tools/install-kubectl-linux/
		# 	kubectlVersion=v1.33.1
		# 	# kubectlVersion=$(curl -L -s https://dl.k8s.io/release/stable.txt)
		# 	curl -o ~/.local/bin/kubectl -L "https://dl.k8s.io/release/$kubectlVersion/bin/linux/amd64/kubectl"
		# fi
		if [ -f "$(which helm)" ]; then
			helmVersion=v3.18.4
			curl -O -L "https://get.helm.sh/helm-$helmVersion-linux-amd64.tar.gz"
			tar -zxvf helm-$helmVersion-linux-amd64.tar.gz
			mv linux-amd64/helm ~/.local/bin/helm
			rm -r linux-amd64
		fi
		if [ -f "$(which terraform)" ]; then
			terrVersion=1.12.2
			curl -O -L "https://releases.hashicorp.com/terraform/$terrVersion/terraform_"$terrVersion"_linux_amd64.zip"
			unzip terraform_"$terrVersion"_linux_amd64.zip -x "LICENSE.txt"
			mv terraform ~/.local/bin/terraform
		fi
	fi

}

_llm_clis() {
	# https://qwenlm.github.io/zh/blog/qwen3-coder
	# bun i -g @qwen-code/qwen-code

	# https://www.anthropic.com/claude-code
	bun i -g @anthropic-ai/claude-code

	# https://openai.com/codex
	# https://github.com/openai/codex
	bun i -g @openai/codex

	# https://github.com/google-gemini/gemini-cli
	bun i -g @google/gemini-cli

	# https://ampcode.com/manual#getting-started-command-line-interface
	bun i -g @sourcegraph/amp@latest

	# https://opencode.ai
	bun i -g opencode-ai

	# https://cursor.com/docs/cli/overview
	curl https://cursor.com/install -fsS | bash

	# go install github.com/charmbracelet/crush@latest

	########################
	## skills
	bun i -g skills vercel-labs/agent-skills
	bun i -g ctx7 # ctx7 skills install
}

case $1 in
"nvim_nightly")
	nvim_nightly
	;;
"tmux")
	update_tmux
	update_tpm
	;;
"fzf")
	update_fzf
	;;
"llm_cli")
	_llm_clis
	;;
*)
	bins
	;;
esac
