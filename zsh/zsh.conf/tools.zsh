
# nvim
update_nvim () {
  version=$(curl -s https://api.github.com/repos/neovim/neovim/tags |jq '.[0].name')
  url="https://github.com/neovim/neovim/releases/download/$version/nvim-linux64.tar.gz"

	wget url

	tar -zxf nvim-linux64.tar.gz
	rm nvim-linux64.tar.gz

	mkdir -p ~/.local/bin/nvim
	sudo rm -rf ~/.local/bin/nvim

	mv nvim-linux64 ~/.local/bin/nvim
	sudo rm -f /usr/local/bin/nvim

	ln -s ~/.local/bin/nvim/bin/nvim /usr/local/bin/nvim

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