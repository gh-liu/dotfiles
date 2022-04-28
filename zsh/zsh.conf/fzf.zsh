#!/bin/sh
FZF_HOME="$DEV_TOOLS/fzf"
function update_fzf() {
    if [ ! -d $FZF_HOME ]; then
        mkdir -p $FZF_HOME
        git clone --depth 1 https://github.com/junegunn/fzf.git $FZF_HOME
    else
        cd $FZF_HOME
        git pull
    fi

    $FZF_HOME/install

    if [ ! -f "$(which fzf)" ]; then
        ln -svf $FZF_HOME/bin/fzf ~/.local/bin/fzf
    fi
}
