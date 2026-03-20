#! /bin/bash

# ======= helper
: "${OS:=$(uname -s | tr '[:upper:]' '[:lower:]')}"
: "${ARCH:=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')}"
gh_latest_tag() {
	gh release list --json tagName,isLatest --jq '.[] | select(.isLatest) | .tagName' -R "$1"
}
# ======= helper

install_kubectl() {
	local version=$(gh_latest_tag kubernetes/kubernetes)
	curl -o ~/.local/bin/kubectl -L "https://dl.k8s.io/release/$version/bin/${OS}/${ARCH}/kubectl"
	chmod +x ~/.local/bin/kubectl
}

install_helm() {
	local version=$(gh_latest_tag helm/helm)
	local PKG=helm-${version}-${OS}-${ARCH}.tar.gz
	local DIR=${OS}-${ARCH}
	curl -O -L "https://get.helm.sh/$PKG"
	tar -zxvf $PKG
	mv $DIR/helm ~/.local/bin/helm
	rm -r $DIR
}

install_terraform() {
	local version=$(gh_latest_tag hashicorp/terraform)
	version=${version#v}
	local PKG=terraform_${version}_${OS}_${ARCH}.zip
	curl -O -L "https://releases.hashicorp.com/terraform/$version/$PKG"
	unzip $PKG -x "LICENSE.txt"
	mv terraform ~/.local/bin/terraform
}

install_bins() {
	if [ -f "$(which go)" ]; then
		export GOPROXY=https://goproxy.io

		# local GOPLSVERSION=$(curl -s https://api.github.com/repos/golang/tools/releases | jq -r ".[0].tag_name" | cut -d/ -f2)
		# go install golang.org/x/tools/gopls@$GOPLSVERSION
		go install golang.org/x/tools/gopls@latest
		go install github.com/go-delve/delve/cmd/dlv@latest
		# go install honnef.co/go/gotraceui/cmd/gotraceui@latest

		go install github.com/junegunn/fzf@latest
		go install github.com/mikefarah/yq/v4@latest

		go install github.com/cli/cli/v2/cmd/gh@latest

		# no protoc, just buf cli
		go install github.com/bufbuild/buf/cmd/buf@latest
		# use BSR(Buf Schema Registry)'s remote plugins
		# go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
		# go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

		go install github.com/boyter/scc/v3@latest

		# go install github.com/jesseduffield/lazygit@latest
		# go install github.com/jesseduffield/lazydocker@latest

		# go install golang.org/x/tools/cmd/present@latest
		go install github.com/abhinav/tmux-fastcopy@latest

		# go install github.com/gohugoio/hugo@latest
		# CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest

		# go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

		# go install github.com/superfly/flyctl@latest
	fi

	if [ -f "$(which bun)" ]; then
		# 	bun i -g tree-sitter-cli
		bun i -g @slidev/cli
	fi

	# if [ -f "$(which uv)" ]; then
	# 	uv tool install --force jupyterlab
	# 	uv tool install --force notebook
	#
	# 	uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
	#
	# 	uv tool install mitmproxy
	# fi

	if [ -f "$(which cargo)" ]; then
		# NOTE: use `cargo binstall` to install bins
		# cargo install cargo-binstall

		cargo install --locked cargo-nextest

		cargo install --locked --bin jj jj-cli
		cargo install --locked worktrunk

		cargo install bat
		cargo install eza
		cargo install zoxide
		# cargo install tealdeer
		# cargo install git-delta difftastic
		cargo install starship --locked
		# cargo install skim
		# cargo install --locked zellij

		# cargo install cargo-binutils

		# cargo install hyperfine # command-line benchmarking
		# cargo install inferno # flamegraph

		# cargo install tree-sitter-cli

		# cargo install shpool

	fi

	# if [ -f "$(which gh)" ]; then
	# 	gh extension install yusukebe/gh-markdown-preview
	# fi

	if [ -f "$(which kubectl)" ]; then
		install_kubectl
	fi

	if [ -f "$(which helm)" ]; then
		install_helm
	fi

	if [ -f "$(which terraform)" ]; then
		install_terraform
	fi

}

if [[ -z "$1" ]]; then
	install_bins
elif declare -f "install_$1" >/dev/null; then
	install_"$1"
else
	echo "unknown component: $1" >&2
	exit 1
fi
