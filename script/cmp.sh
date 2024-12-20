#!/usr/bin/env bash

[ -f "$(which rustup)" ] && rustup completions zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_rustup
[ -f "$(which gh)" ] && gh completion -s zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_gh
[ -f "$(which just)" ] && just --completions=zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_just
[ -f "$(which git-absorb)" ] && git-absorb --gen-completions zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_git-absorb
[ -f "$(which docker)" ] && docker completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_docker
[ -f "$(which podman)" ] && podman completion zsh >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_podman
[ -f "$(which bun)" ] && SHELL=zsh bun completions >"$XDG_CONFIG_HOME"/zsh/zsh-completions/_bun
