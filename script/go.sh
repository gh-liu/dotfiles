#! /usr/bin/bash
function update_gotools() {
	# cd $GOBIN
	# echo enter $PWD

	export GOPROXY=https://goproxy.io
	local go_tools=(
		"golang.org/x/tools/gopls"
		"github.com/uudashr/gopkgs/cmd/gopkgs"
		"github.com/ramya-rao-a/go-outline"
		"github.com/haya14busa/goplay/cmd/goplay"
		"github.com/fatih/gomodifytags"
		"github.com/josharian/impl"
		"github.com/cweill/gotests/..."
		"github.com/golangci/golangci-lint/cmd/golangci-lint"
		"github.com/rinchsan/gosimports/cmd/gosimports"
		"github.com/go-delve/delve/cmd/dlv"
		"github.com/klauspost/asmfmt/cmd/asmfmt"
		"github.com/kisielk/errcheck"
		"github.com/davidrjenni/reftools/cmd/fillstruct"
		"github.com/rogpeppe/godef"
		"golang.org/x/tools/cmd/goimports"
		"golang.org/x/lint/golint"
		"github.com/mgechev/revive"
		"honnef.co/go/tools/cmd/staticcheck"
		"golang.org/x/tools/cmd/gorename"
		"github.com/jstemmer/gotags"
		"golang.org/x/tools/cmd/guru"
		"honnef.co/go/tools/cmd/keyify"
		"github.com/fatih/motion"
		"github.com/koron/iferr"
		"google.golang.org/protobuf/cmd/protoc-gen-go"
		"google.golang.org/grpc/cmd/protoc-gen-go-grpc"
		"golang.org/x/perf/cmd/benchstat"
		"github.com/aclements/perflock/cmd/perflock"
		"mvdan.cc/gofumpt"
	)

	echo "update go tools"
	for tool in $go_tools; do
		GO111MODULE=on go install $tool@latest
		echo "update tool: [$tool@latest] success."
	done

	# cd -
}

function update_go() {
	mkdir -p $GOPATH && cd $GOPATH && cd ..

	GOVERSION=$1
	if [ -z $GOVERSION ]; then
		GOVERSION=$(curl -s 'https://go.dev/dl/?mode=json' | grep '"version"' | sed 1q | awk '{print $2}' | tr -d ',"') # get latest go version
	fi

	GOARCH=$(if [[ $(uname -m) == "x86_64" ]]; then echo amd64; else echo $(uname -m); fi) # get either amd64 or arm64 (darwin/m1)

	wget "https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz"

	echo "update golang to $GOVERSION"

	if cmd_exist go; then
		OLDVERSION=$(go version | awk '{print $3}')
		if [ ! "$OLDVERSION" = "$GOVERSION" ]; then
			echo "old version: $OLDVERSION"
			# bakeup old version
			rm -rf $PWD/$OLDVERSION
			mv $PWD/go $PWD/$OLDVERSION
		fi
	fi

	tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz && rm $GOVERSION.linux-$GOARCH.tar.gz
	echo "install $GOVERSION in $PWD success."
}

if [[ $1 == "go" ]]; then
	update_go
fi

if [[ $1 == "gotools" ]]; then
	update_gotools
fi
