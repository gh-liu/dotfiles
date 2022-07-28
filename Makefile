help: ## Display this help message
	@cat $(MAKEFILE_LIST) | grep -e "^[a-zA-Z_\-]*: *.*## *" | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: update_go
update_go:
	@ ./script/go.sh go

.PHONY: update_gotools
update_gotools:
	@ ./script/go.sh gotools

.PHONY: update_nvim
update_nvim:
	@ ./script/nvim.sh

.PHONY: update_lsp_bin
update_lsp_bin:
	@ ./script/lsp_bin.sh

.PHONY: update_nodejs
update_nodejs:
	@ ./script/nodejs.sh nodejs

.PHONY: update_npm
update_npm:
	@ ./script/nodejs.sh npm

.PHONY: update_fzf
update_fzf:
	@ ./script/fzf.sh

.PHONY: update_lua
update_lua:
	@ ./script/lua.sh