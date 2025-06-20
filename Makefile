help: ## Print help message
	@echo "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\033[36m\1\\033[m:\2/' | column -c2 -t -s :)"

## =======================================
.PHONY: dev
dev: zsh tmux nvim_nightly
	@echo "===============DONE====================="

.PHONY: zsh
zsh: starship
	@ ln -svf $$HOME/tools/dotfiles/xdg_config/zsh/.zshenv ~/.zshenv

.PHONY: starship
starship:
	@echo "========================================"
	@echo "Installing starship..."
	curl -fsSL https://starship.rs/install.sh | sh
	@echo "========================================"

.PHONY: tmux
tmux:
	@ ./script/bins.sh tmux

.PHONY: nvim_nightly
nvim_nightly:
	@ ./script/bins.sh nvim_nightly
## =======================================

.PHONY: ghostty
ghostty:
	@ ln -svf $$HOME/tools/dotfiles/xdg_config/ghostty ~/.config/ghostty
	
.PHONY: hammerspoon
hammerspoon:
	@ ln -svf $$HOME/tools/dotfiles/xdg_config/hammerspoon/init.lua ~/.hammerspoon/init.lua
	
.PHONY: brew
brew:
	@ brew bundle install --file=$$HOME/tools/dotfiles/xdg_config/Brewfile
.PHONY: brewdump
brewdump:
	@ brew bundle dump --force --file=$$HOME/tools/dotfiles/xdg_config/Brewfile

.PHONY: langs
langs:
	@ ./script/lang.sh go
	@ ./script/lang.sh rust
	@ ./script/lang.sh zig
	@ ./script/lang.sh lua
	@ ./script/lang.sh nodejs
	@ ./script/lang.sh python

.PHONY: patchs
patchs:
	@cp $$(pwd)/patch/nvimfoldcolumn.patch $$LIU_TOOLS/neovim
