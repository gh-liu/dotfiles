#!/bin/zsh
function extract {
	if [ -z "$1" ]; then
		echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
	else
		if [ -f $1 ]; then
			case $1 in
			*.tar.bz2) tar xvjf $1 ;;
			*.tar.gz) tar xvzf $1 ;;
			*.tar.xz) tar xvJf $1 ;;
			*.lzma) unlzma $1 ;;
			*.bz2) bunzip2 $1 ;;
			*.rar) unrar x -ad $1 ;;
			*.gz) gunzip $1 ;;
			*.tar) tar xvf $1 ;;
			*.tbz2) tar xvjf $1 ;;
			*.tgz) tar xvzf $1 ;;
			*.zip) unzip $1 ;;
			*.Z) uncompress $1 ;;
			*.7z) 7z x $1 ;;
			*.xz) unxz $1 ;;
			*.exe) cabextract $1 ;;
			*) echo "extract: '$1' - unknown archive method" ;;
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

function wget_archive_and_extract {
	URL=$1
	FILENAME=${URL##*/}
	wget $URL -O $FILENAME
	extract $FILENAME
	rmi $FILENAME
}
alias wgetae='wget_archive_and_extract '

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

function touch2() { mkdir -p "$(dirname "$1")" && touch "$1"; }

function mkdir_and_cd() {
	mkdir -p -- "$1" && cd -P -- "$1"
}
alias mcd='mkdir_and_cd '

function abspath() {
	if [ -d "$1" ]; then
		echo "$(
			cd $1
			pwd
		)"
	elif [ -f "$1" ]; then
		if [[ $1 == */* ]]; then
			echo "$(
				cd ${1%/*}
				pwd
			)/${1##*/}"
		else
			echo "$(pwd)/$1"
		fi
	fi
}

# list the PATH separated by new lines
alias lspath='echo $PATH | tr ":" "\n"'
alias lsfpath='echo $fpath | tr " " "\n"'

function ssh-copy-id2() {
	if [ -z "$1" ]; then
		echo "Usage: ssh-copy-id2 user@ip"
	else

		RARGET=$1
		User="$(cut -d'@' -f1 <<<$RARGET)"
		IP="$(cut -d'@' -f2 <<<$RARGET)"
		Name="$(cut -d'.' -f4 <<<$IP)"

		echo "" >>~/.ssh/config
		echo "Host $Name" >>~/.ssh/config
		echo "HostName $IP" >>~/.ssh/config
		echo "User $User" >>~/.ssh/config

		ssh-copy-id $Name
	fi
}
