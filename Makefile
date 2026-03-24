.DEFAULT_GOAL := help

DOTFILES_DIR := $(CURDIR)
XDG_CONFIG_DIR := $(DOTFILES_DIR)/xdg_config
BREWFILE := $(XDG_CONFIG_DIR)/Brewfile
DEVLANGS := ./xdg_config/bin/devlangs
NVIM_PATCH := $(DOTFILES_DIR)/patch/nvimfoldcolumn.patch

.PHONY: help zsh starship ghostty hammerspoon brew brewdump langs patchs patches

help: ## Print available targets
	@echo "$$(grep -hE '^[[:alnum:]_%-]+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\033[36m\1\\033[m:\2/' | column -c2 -t -s :)"

zsh: starship ## Link zsh config entrypoint
	@ln -svf $(XDG_CONFIG_DIR)/zsh/.zshenv ~/.zshenv

starship: ## Install starship prompt
	@echo "========================================"
	@echo "Installing starship..."
	curl -fsSL https://starship.rs/install.sh | sh
	@echo "========================================"

ghostty: ## Link Ghostty config
	@ln -svf $(XDG_CONFIG_DIR)/ghostty ~/.config/ghostty

hammerspoon: ## Link Hammerspoon config
	@ln -svf $(XDG_CONFIG_DIR)/hammerspoon/init.lua ~/.hammerspoon/init.lua

brew: ## Install packages from Brewfile
	@brew bundle install --file=$(BREWFILE)

brewdump: ## Dump current Homebrew bundle to Brewfile
	@brew bundle dump --force --file=$(BREWFILE)

langs: ## Install language runtimes and tooling
	@$(DEVLANGS) go
	@$(DEVLANGS) rust
	@$(DEVLANGS) zig
	@$(DEVLANGS) nodejs
	@$(DEVLANGS) uv
	@$(DEVLANGS) emmylua_ls

patchs: ## Copy local Neovim patch into $$LIU_TOOLS/neovim
	@cp $(NVIM_PATCH) $$LIU_TOOLS/neovim

patches: patchs ## Alias of patchs
