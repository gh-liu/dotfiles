# https://github.com/zsh-users/zsh-completions
fpath=($HOME/.zsh-plugins/zsh-completions/src $fpath)

fpath=($XDG_CONFIG_HOME/zsh/zsh-completions $fpath)

# Should be called before compinit
zmodload zsh/complist
bindkey -M menuselect 'H' vi-backward-char
bindkey -M menuselect 'K' vi-up-line-or-history
bindkey -M menuselect 'J' vi-down-line-or-history
bindkey -M menuselect 'L' vi-forward-char
# bindkey -M menuselect '^xg' clear-screen
bindkey -M menuselect 'U' undo

_comp_options+=(globdots) # With hidden files
autoload -U +X bashcompinit && bashcompinit
autoload -U +X compinit && compinit
# autoload -U compinit && compinit

setopt MENU_COMPLETE # Automatically highlight first element of completion menu

zstyle ':completion:*' menu select
zstyle ':completion:*:*:*:*:descriptions' format '%F{blue}-- %D %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'

## case-insensitive (uppercase from lowercase) completion
# zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
## case-insensitive (all) completion
#zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
## case-insensitive,partial-word and then substring completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
