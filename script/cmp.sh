#!/usr/bin/env bash

podman completion zsh >$XDG_CONFIG_HOME/zsh/zsh-completions/_podman
rustup completions zsh >$XDG_CONFIG_HOME/zsh/zsh-completions/_rustup
gh completion -s zsh >$XDG_CONFIG_HOME/zsh/zsh-completions/_gh
just --completions=zsh >$XDG_CONFIG_HOME/zsh/zsh-completions/_just
git-absorb --gen-completions zsh >$XDG_CONFIG_HOME/zsh/zsh-completions/_git-absorb
