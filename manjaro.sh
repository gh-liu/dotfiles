#!/bin/bash

# Partition 
# 1、创建 1024M fat32 格式，挂载到 /boot/efi 并设置 boot 和 esf 属性
# 2、创建 16G linuxswap 格式，这个 8G 根据内存的一半设置
# 3、创建 100G ext4 格式，挂载到 /
# 4、创建 一个挂载到 /home 的分区作为用户数据目录

# change manjaro mirrors
# sudo pacman-mirrors -i -c China -m rank
# sudo pacman -Syy
# sudo pacman -Syu

# change archlinuxcn mirrors
# sudo vi /etc/pacman.conf 
# [archlinuxcn] 
# SigLevel = Optional TrustedOnly 
# Server = https://mirrors.cloud.tencent.com/archlinuxcn/$arch
# sudo pacman -Syy
# sudo pacman -Syu

# install software
echo -e "\n" | sudo pacman -S archlinuxcn-keyring
echo -e "\n" | sudo pacman -S yay
echo -e "\n" | sudo pacman -S ibus-rime

echo -e "\n" | sudo pacman -S base-devel coreutils
echo -e "\n" | sudo pacman -S zsh vim tmux tmuxp
echo -e "\n" | sudo pacman -S jq bat fzf ctags
echo -e "\n" | sudo pacman -S docker docker-compose 
echo -e "\n" | sudo pacman -S htop tcpdump strace perf httpie
echo -e "\n" | sudo pacman -S cmake gdb lldb 
echo -e "\n" | sudo pacman -S virtualbox vagrant 
echo -e "\n" | sudo pacman -S ripgrep the_silver_searcher vagrant cloc nodejs npm github-cli neofetch cmatrix

echo -e "\n" | sudo pacman -S vlc spotify qv2ray google-chrome obsidian visual-studio-code-insiders-bin typora menulibre telegram-desktop 

echo -e "\n" | yay -S direnv
echo -e "\n" | yay -S xmind-2020 smartgit wechat-uos
echo -e "\n" | yay -S wps-office-cn wps-office-mui-zh-cn ttf-wps-fonts

# env
if [ ! -d "~/env/" ]; then
    mkdir -p ~/env/
fi

## install go
if [ ! -d "~/env/golang/" ]; then
    mkdir -p ~/env/golang/
fi
cd ~/env/golang/ 

# tool
if [ ! -d "~/tool/" ]; then
    mkdir -p ~/tool/
fi

## install oh-my-zsh
cd ~/tool
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"

## install antojump
git clone https://github.com/wting/autojump.git
cd autojump
./install.py



# Clipboard Indicator by Tudmotu
# Hide Top Bar by tuxor1337    maybe something wrong
# IBus Tweaker by grroot
# OpenWeather by jens
# Sound Input & Output Device Chooser by kgshank
# Screenshot Tool by oal

# gnome-shell extension
# Dash to Dock by michele_g
# Desktop Icons NG (DING) by rastersoft
# GSConnect by andyholmes
# KStatusNotifierItem/AppIndicator Support by 3v1n0
# Panel OSD by jens
# Unite by hardpixel
# User Themes by fmuellner


# swap ctrl and capsLock:
# tweaks-> keyboard&mouse->addtional layout options ->ctrl options
