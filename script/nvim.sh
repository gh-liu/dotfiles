#! /usr/bin/bash
function cmd_exist() {
	if ! command -v $1 &>/dev/null; then
		return 1
	fi
	return 0
}

function update_vim() {
	sudo apt-get install lua5.1 liblua5.1-dev

	mkdir -p $HOME/tools/vim
	git_clone_or_update https://github.com/vim/vim.git $HOME/tools/vim
	cd $HOME/tools/vim/src

	./configure \
		--with-features=huge \
		--enable-multibyte \
		--enable-luainterp \
		--enable-fail-if-missing

	sudo make
	sudo make install
	ln -svf $HOME/tools/vim/src/vim $HOME/.local/bin
}

function update_nvim() {
	echo "========================================BEGIN"

	version=$(curl -s https://api.github.com/repos/neovim/neovim/tags | jq -f '.[0].name')
	echo "updating nvim to $version..."

	NVIMINSTALLHOME=$HOME/tool/nvim
	mkdir -p $NVIMINSTALLHOME && cd $NVIMINSTALLHOME

	url="https://github.com/neovim/neovim/releases/download/$version/nvim-linux64.tar.gz"
	wget $url -q --show-progress

	tar -zxf nvim-linux64.tar.gz
	rm nvim-linux64.tar.gz

	mkdir -p ~/.local/bin

	sudo rm -rf ~/.local/bin/nvim
	mv nvim-linux64 ~/.local/bin/nvim

	sudo rm -f /usr/local/bin/nvim
	sudo ln -s ~/.local/bin/nvim/bin/nvim /usr/local/bin/nvim

	[ ! -z "$ISWSL" ] && install_win32yank

	nvim --version

	# nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
	nvim --headless "+Lazy! sync" +qa

	echo "========================================END"
}

function install_win32yank() {
	echo "========================================BEGIN"
	echo "install win32yank"

	curl -sLo/tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip
	unzip -p /tmp/win32yank.zip win32yank.exe >/tmp/win32yank.exe
	chmod +x /tmp/win32yank.exe
	sudo mv /tmp/win32yank.exe /usr/local/bin/

	echo "========================================END"
}

update_nvim $@
