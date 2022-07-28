#! /usr/bin/bash
function update_lsp_bin() {
	go install golang.org/x/tools/gopls@latest
	go install mvdan.cc/sh/v3/cmd/shfmt@latest

	npm i -g vscode-langservers-extracted

	npm i -g yaml-language-server

	npm i -g bash-language-server

	npm i -g vim-language-server

	npm i -g typescript typescript-language-server

	npm i -g dockerfile-language-server-nodejs
}
update_lsp_bin
