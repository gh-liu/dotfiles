# .zshenv is always sourced.
# Most ${ENV_VAR} variables should be saved here.
# It is loaded before .zshrc
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CONFIG_HOME=$HOME/tools/dotfiles/xdg_config
export ZDOTDIR=$XDG_CONFIG_HOME/zsh
# Disable Ubuntu's global compinit from /etc/zsh/zshrc so our own completion
# setup can build .zcompdump after custom fpath entries are in place.
export skip_global_compinit=1
