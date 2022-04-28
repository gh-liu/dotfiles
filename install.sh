#!/bin/bash

platform=$(lsb_release -d | awk -F"\t" '{print $2}' | awk '{print $1}')

# check if ubuntu
if [ $platform == "Ubuntu" ]; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl jq bat git ssh
    sudo apt install -y zsh tmux tmuxp
    sudo apt install -y linux-tools-common linux-tools-$(uname -r) linux-tools-generic

    sudo apt install -y ripgrep silversearcher-ag fd-find
    sudo apt install -y xsel hugo direnv graphviz

    sudo apt install -y build-essential libssl-dev

    # sudo apt install -y autoconf automake pkg-config
    # sudo apt install -y apache2-utils ngrep
    # sudo apt install -y gdb binutils cgroup-tools
    # sudo apt install -y python python3-pip
    # sudo apt install -y libsqlite3-dev libevent-dev
    # sudo apt install -y tldr protobuf-compiler
    # sudo apt install -y pax-utils elfutils prelink
    # sudo apt install -y ttf-mscorefonts-installer

    ### install docker(https://docs.docker.com/engine/install/ubuntu/)
    ### intsall docker-compose(https://docs.docker.com/compose/install/)
    ### install stylua(https://github.com/JohnnyMorganz/StyLua)

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt update
    sudo apt install -y gh

    sudo apt install -y clangd-12
# apt proxy
# sudo touch /etc/apt/apt.conf.d/proxy.conf
# sudo vi /etc/apt/apt.conf.d/proxy.conf
# Acquire::http::Proxy "http://user:password@proxy.server:port/";
# Acquire::https::Proxy "http://user:password@proxy.server:port/";

# https://askubuntu.com/questions/33774/how-do-i-remap-the-caps-lock-and-ctrl-keys
fi

## directories
tools=$HOME/tools
mkdir -p $tools
mkdir -p $HOME/dev/{golang,nodejs,python3,lua}
mkdir -p $HOME/env/{golang,nodejs,python3,lua}

## proxy
echo -n "Enter your proxy:"
read _PROXY_HTTP
export proxy=$_PROXY_HTTP # Todo: need set by youself
export http_proxy=$proxy
export https_proxy=$proxy

## dotfiles
dotfilespath=$tools/dotfiles
git clone https://github.com/gh-liu/dotfiles.git $dotfilespath

### tmux
#### tpm
mkdir -p $HOME/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm

#### tmux config
mv -v $HOME/.tmux.conf $HOME/.tmux.conf.old 2>/dev/null
ln -svf $dotfilespath/tmux/tmux.conf $HOME/.tmux.conf

### zsh config
mv -v $HOME/.zshrc $HOME/.zshrc.old 2>/dev/null
ln -svf $dotfilespath/zsh/zsh.conf $HOME/.zsh.conf
ln -svf $dotfilespath/zsh/zshrc $HOME/.zshrc

chsh -s $(which zsh)

#### starship
ln -svf $dotfilespath/zsh/starship/starship.toml $HOME/.config/starship.toml
# starship will be installed in zshrc.
# sh -c "$(curl -fsSL https://starship.rs/install.sh)"

source $HOME/.zshrc

### nvim config
mkdir -p $HOME/.config
ln -svf $dotfilespath/nvim $HOME/.config/nvim

### utils
git clone https://github.com/wg/wrk.git $tools/wrk
cd $tools/wrk
sudo make
sudo cp wrk /usr/local/bin

git clone https://github.com/universal-ctags/ctags.git $tools/ctags
cd $tools/ctags
./autogen.sh
./configure # --prefix=/where/you/want defaults to /usr/local
make
sudo make install
