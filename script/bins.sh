#! /bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. $SCRIPT_DIR/helper.sh --source-only

bins() {
	if [ -f "$(which go)" ]; then
		export GOPROXY=https://goproxy.io

		# local GOPLSVERSION=$(curl -s https://api.github.com/repos/golang/tools/releases | jq -r ".[0].tag_name" | cut -d/ -f2)
		# go install golang.org/x/tools/gopls@$GOPLSVERSION
		go install golang.org/x/tools/gopls@latest
		go install github.com/go-delve/delve/cmd/dlv@latest
		# go install honnef.co/go/gotraceui/cmd/gotraceui@latest

		# no protoc, just buf cli
		go install github.com/bufbuild/buf/cmd/buf@latest
		# use BSR(Buf Schema Registry)'s remote plugins
		# go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
		# go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

		go install github.com/boyter/scc/v3@latest

		go install github.com/jesseduffield/lazygit@latest
		go install github.com/jesseduffield/lazydocker@latest

		# go install golang.org/x/tools/cmd/present@latest
		go install github.com/abhinav/tmux-fastcopy@latest

		# go install github.com/gohugoio/hugo@latest
		# CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest

		# go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

		go install github.com/junegunn/fzf@latest
		go install github.com/mikefarah/yq/v4@latest

		go install github.com/superfly/flyctl@latest
	fi

	if [ -f "$(which bun)" ]; then
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

case $1 in
*)
	bins
	;;
esac
