#!/bin/bash
BASE=$(pwd)

# INSTALL

## tmux
mkdir -p ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

## vim-plug
# mkdir -p ~/.vim/autoload
# curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
#     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

## ohmyzsh and plugin
git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
# git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search


mkdir -p ~/tool
mkdir -p ~/code/golang
mkdir -p ~/env/golang

# CONFIG

## scripts
mkdir -p ~/bin
for v in $BASE/bin/*; do
  ln -svf "$v" ~/bin
done

## zsh
mv -v ~/.zshrc ~/.zshrc.old 2> /dev/null
for v in $BASE/zsh/.common_*; do
  ln -svf "$v" ~/
done
ln -svf $BASE/zsh/.zshrc ~/.zshrc
ln -svf $BASE/zsh/7triones.zsh-theme ~/.oh-my-zsh/themes/7triones.zsh-theme
source ~/.zshrc

## tmux
mv -v ~/.tmux.conf ~/.tmux.conf.old 2> /dev/null
ln -svf $BASE/tmux/tmux.conf ~/.tmux.conf

## vim
for v in $BASE/vim/*.vim; do
  ln -svf "$v" ~/.vim
done
mv -v ~/.vimrc ~/.vimrc.old 2> /dev/null
ln -svf $BASE/vim/vimrc ~/.vimrc
ln -svf $BASE/vim/UltiSnips ~/.vim/UltiSnips
ln -svf $BASE/coc/coc-settings.json ~/.vim/coc-settings.json
# Make sure that the vim-plug have installed.
vim +PlugInstall +qall

## nvim
mkdir -p ~/.config/nvim
ln -svf $(pwd)/nvim/* ~/.config/nvim

## alacritty
ln -svf $BASE/alacritty/alacritty.yml ~/.alacritty.yml

## autojump
git clone git://github.com/wting/autojump.git ~/tool/autojump
cd ~/tool/autojump
./install.py

# pip install --user tmuxp
