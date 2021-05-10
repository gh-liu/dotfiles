#!/bin/bash
BASE=$(pwd)

## tmux
mkdir -p ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# tmux.conf
mv -v ~/.tmux.conf ~/.tmux.conf.old 2> /dev/null
ln -sf $BASE/tmux/tmux.conf ~/.tmux.conf

## vim
# theme
mkdir -p ~/.vim/colors
curl -o ~/.vim/colors/jellybeans.vim https://raw.githubusercontent.com/nanotech/jellybeans.vim/master/colors/jellybeans.vim
# plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# vimrc
mv -v ~/.vimrc ~/.vimrc.old 2> /dev/null
ln -sf $BASE/vim/vimrc ~/.vimrc
ln -sf $BASE/vim/config.vim ~/.vim/config.vim
ln -sf $BASE/vim/plugins.vim ~/.vim/plugins.vim

ln -sf $BASE/coc/coc-settings.json ~/.vim/coc-settings.json

vim +PlugInstall +qall

# zsh
# zsh theme and plugin
ln -sf $BASE/zsh/7triones.zsh-theme ~/.oh-my-zsh/themes/7triones.zsh-theme
mv -v ~/.zshrc ~/.zshrc.old 2> /dev/null
ln -sf $BASE/zsh/zshrc ~/.zshrc
ln -sf $BASE/zsh/common_env ~/.common_env
ln -sf $BASE/zsh/common_func ~/.common_func
ln -sf $BASE/zsh/common_alias ~/.common_alias
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
source ~/.zshrc


# just link the config
# 
# mv -v ~/.tmux.conf ~/.tmux.conf.old 2> /dev/null
# ln -sf $BASE/tmux/tmux.conf ~/.tmux.conf

# mv -v ~/.vimrc ~/.vimrc.old 2> /dev/null
# ln -sf $BASE/vim/vimrc ~/.vimrc
# ln -sf $BASE/vim/config.vim ~/.vim/config.vim
# ln -sf $BASE/vim/plugins.vim ~/.vim/plugins.vim

# generate the 'goplsPath' of 'coc-settings.json'
# sed -i "s:_GOBIN:$GOBIN:" ./coc/coc-settings.json
# sed -i "s:$GOBIN:_GOBIN:" ./coc/coc-settings.json
# ln -sf $BASE/coc/coc-settings.json ~/.vim/coc-settings.json

# mv -v ~/.zshrc ~/.zshrc.old 2> /dev/null
# ln -sf $BASE/zsh/zshrc ~/.zshrc
# ln -sf $BASE/zsh/common_env ~/.common_env
# ln -sf $BASE/zsh/common_func ~/.common_func
# ln -sf $BASE/zsh/common_alias ~/.common_alias
# ln -sf $BASE/zsh/7triones.zsh-theme ~/.oh-my-zsh/themes/7triones.zsh-theme

# alacritty
# ln -sf $(pwd)/alacritty/alacritty.yml ~/.alacritty.yml