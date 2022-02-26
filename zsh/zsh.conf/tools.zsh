#!/bin/sh

# proxy set and unset
# set_proxy(){
#     PROXY_HTTP=http://127.0.0.1:1081

#     export http_proxy="${PROXY_HTTP}"
#     export HTTP_PROXY="${PROXY_HTTP}"

#     export https_proxy="${PROXY_HTTP}"
#     export HTTPS_proxy="${PROXY_HTTP}"

#     echo "set proxy to $PROXY_HTTP"
# }
# set_proxy

# unset_proxy(){
#     unset http_proxy
#     unset HTTP_PROXY
#     unset https_proxy
#     unset HTTPS_PROXY
#     echo "unset proxy"
# }

update_go () {
  set e

  cd $GOPATH && cd ..

  GOVERSION=$(curl -s 'https://go.dev/dl/?mode=json' | grep '"version"' | sed 1q | awk '{print $2}' | tr -d ',"')  # get latest go version  
  GOARCH=$(if [[ $(uname -m) == "x86_64" ]] ; then echo amd64; else echo $(uname -m); fi) # get either amd64 or arm64 (darwin/m1)

  wget "https://dl.google.com/go/$GOVERSION.linux-$GOARCH.tar.gz"

  OLDVERSION=$(go version | awk '{print $3}')
  echo "old version: $OLDVERSION"
  # bake old version
  mv $PWD/go $PWD/$OLDVERSION

  tar -zxvf $GOVERSION.linux-$GOARCH.tar.gz && rm $GOVERSION.linux-$GOARCH.tar.gz
  echo "install $GOVERSION in $PWD success."
}

update_gotools () {
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

# nvim
update_nvim () {
  version=$(curl -s https://api.github.com/repos/neovim/neovim/tags |jq '.[0].name')
  version=${version//\"/}
  echo "update nvim to $version"

  url="https://github.com/neovim/neovim/releases/download/$version/nvim-linux64.tar.gz"
  echo "wget $url -q --show-progress"
	wget $url

	tar -zxf nvim-linux64.tar.gz
	rm nvim-linux64.tar.gz

  mkdir -p ~/.local/bin
  
	sudo rm -rf ~/.local/bin/nvim
	mv nvim-linux64 ~/.local/bin/nvim

	sudo rm -f /usr/local/bin/nvim
	sudo ln -s ~/.local/bin/nvim/bin/nvim /usr/local/bin/nvim

  nvim --version
}

# archives
function extract {
  if [ -z "$1" ]; then
    echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
  else
    if [ -f $1 ]; then
      case $1 in
        *.tar.bz2)   tar xvjf $1    ;;
        *.tar.gz)    tar xvzf $1    ;;
        *.tar.xz)    tar xvJf $1    ;;
        *.lzma)      unlzma $1      ;;
        *.bz2)       bunzip2 $1     ;;
        *.rar)       unrar x -ad $1 ;;
        *.gz)        gunzip $1      ;;
        *.tar)       tar xvf $1     ;;
        *.tbz2)      tar xvjf $1    ;;
        *.tgz)       tar xvzf $1    ;;
        *.zip)       unzip $1       ;;
        *.Z)         uncompress $1  ;;
        *.7z)        7z x $1        ;;
        *.xz)        unxz $1        ;;
        *.exe)       cabextract $1  ;;
        *)           echo "extract: '$1' - unknown archive method" ;;
      esac
    else
      echo "$1 - file does not exist"
    fi
  fi
}
alias extr='extract '

function extract_and_remove {
  extract $1
  rm -f $1
}
alias extrr='extract_and_remove '

function abspath() {
    if [ -d "$1" ]; then
        echo "$(cd $1; pwd)"
    elif [ -f "$1" ]; then
        if [[ $1 == */* ]]; then
            echo "$(cd ${1%/*}; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
    fi
}
alias abspath="abspath "

function install_from_git {
  URL=$1
  DIRNAME="/tmp/${URL##*/}"
  git clone $URL $DIRNAME
  pushd $DIRNAME
  make
  sudo make install
  popd
  rm -rf $DIRNAME
}
alias ifg="install_from_git "

function wget_archive_and_extract {
  URL=$1
  FILENAME=${URL##*/}
  wget $URL -O $FILENAME
  extract $FILENAME
  rmi $FILENAME
}
alias wgetae='wget_archive_and_extract '

# Open your $EDITOR in the lower 3rd of your tmux window until you exit it.
peek() { tmux split-window -p 33 "$EDITOR" "$@" }

# https://www.commandlinefu.com/commands/view/9065/what-is-the-use-of-this-switch-
function manswitch () { man $1 | less -p "^ +$2"; }

# mkdir and cd
mc () {
	mkdir -p -- "$1" && cd -P -- "$1"
}