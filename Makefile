help: ## Print help message
	@echo "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\033[36m\1\\033[m:\2/' | column -c2 -t -s :)"

.PHONY: zsh
zsh: starship
	@ ln -svf $$HOME/tools/dotfiles/.zshenv ~/.zshenv

.PHONY: vim
vim:
	@ ln -svf $$HOME/tools/dotfiles/vimrc ~/.vimrc

.PHONY: starship
starship:
	@echo "========================================"
	@echo "Installing starship..."
	curl -fsSL https://starship.rs/install.sh | sh
	@echo "========================================"

.PHONY: tmux
tmux:
	@echo "========================================"
	@echo "Installing tpm..."
	git clone https://github.com/tmux-plugins/tpm $$XDG_CONFIG_HOME/tmux/plugins/tpm
	@echo "========================================"


.PHONY: nvim
nvim:
	@ ./script/nvim.sh

.PHONY: nvim_nightly
nvim_nightly:
	@ ./script/nvim.sh nightly

.PHONY: langs
langs:
	@ ./script/lang.sh go
	@ ./script/lang.sh lua
	@ ./script/lang.sh rust
	@ ./script/lang.sh nodejs
