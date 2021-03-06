#! /usr/bin/bash
function update_nvim() {
	version=$1

	if [ -z $version ]; then
		version=$(curl -s https://api.github.com/repos/neovim/neovim/tags | jq '.[0].name')
		version=${version//\"/}
	fi

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

	if cmd_exist pip; then
		pip install pynvim
	fi

	if cmd_exist npm; then
		npm i -g neovim
	fi

	nvim --version
}

function cmd_exist() {
	if ! command -v $1 &>/dev/null; then
		return 1
	fi
	return 0
}

update_nvim
