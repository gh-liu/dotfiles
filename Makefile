help: ## Print help message
	@echo "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\033[36m\1\\033[m:\2/' | column -c2 -t -s :)"

.PHONY: dev
dev: zsh tmux nvim_nightly
	@echo "===============DONE====================="

.PHONY: zsh
zsh: starship
	@ ln -svf $$HOME/tools/dotfiles/.zshenv ~/.zshenv

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

.PHONY: langs
langs:
	@ ./script/lang.sh go
	@ ./script/lang.sh rust
	@ ./script/lang.sh zig
	@ ./script/lang.sh lua
	@ ./script/lang.sh nodejs
