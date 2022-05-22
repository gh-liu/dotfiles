#!/bin/bash

## proxy
echo -n "Enter your proxy:"
read _PROXY_HTTP
export http_proxy=$_PROXY_HTTP
export https_proxy=$_PROXY_HTTP

LinuxDistro=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')

if [ $LinuxDistro = "Ubuntu" ]; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl jq bat git git-flow ssh
    sudo apt install -y zsh tmux tmuxp
    sudo apt install -y linux-tools-common linux-tools-$(uname -r) linux-tools-generic

    sudo apt install -y ripgrep silversearcher-ag fd-find
    sudo apt install -y xsel hugo direnv graphviz

    sudo apt install -y build-essential libssl-dev

    sudo apt install -y autoconf automake pkg-config

    sudo apt install -y ca-certificates gnupg lsb-release

    sudo apt install -y gh
    sudo apt install -y zip unzip
    sudo apt install -y clangd-12
    # sudo apt install -y apache2-utils ngrep
    # sudo apt install -y gdb binutils cgroup-tools
    # sudo apt install -y python python3-pip
    # sudo apt install -y libsqlite3-dev libevent-dev
    # sudo apt install -y tldr protobuf-compiler
    # sudo apt install -y pax-utils elfutils prelink
    # sudo apt install -y ttf-mscorefonts-installer

    ### install docker(https://docs.docker.com/engine/install/ubuntu/)
    sudo apt remove -y docker docker.io containerd runc
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    ### intsall docker-compose(https://docs.docker.com/compose/install/)
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    version=$(curl -s https://api.github.com/repos/docker/compose/tags | jq '.[0].name')
    version=${version//\"/}
    curl -SL https://github.com/docker/compose/releases/download/$version/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose



    # apt proxy
    sudo touch /etc/apt/apt.conf.d/proxy.conf
    sudo tee -a /etc/apt/apt.conf.d/proxy.conf <<EOF
Acquire::http::Proxy "$http_proxy";
Acquire::https::Proxy "$https_proxy";
EOF

# https://askubuntu.com/questions/33774/how-do-i-remap-the-caps-lock-and-ctrl-keys
fi

## directories
tools=$HOME/tools
mkdir -p $tools
mkdir -p $HOME/dev/{golang,nodejs,python3,lua}
mkdir -p $HOME/env/{golang,nodejs,python3,lua}

## dotfiles
dotfilespath=$tools/dotfiles
git clone https://github.com/gh-liu/dotfiles.git $dotfilespath

### nvim config
rm -rf $HOME/.config/nvim
mkdir -p $HOME/.config/nvim
ln -svf $dotfilespath/nvim $HOME/.config/

### tmux
#### tpm
rm -rf $HOME/.tmux/plugins/tpm
mkdir -p $HOME/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm

#### tmux config
mv -v $HOME/.tmux.conf $HOME/.tmux.conf.old 2>/dev/null
ln -svf $dotfilespath/tmux/tmux.conf $HOME/.tmux.conf

### zsh config
rm -rf $HOME/.zsh.conf
mv -v $HOME/.zshrc $HOME/.zshrc.old 2>/dev/null
ln -svf $dotfilespath/zsh/zsh.conf $HOME/.zsh.conf
ln -svf $dotfilespath/zsh/zshrc $HOME/.zshrc
touch $HOME/.zsh.conf/custom.zsh
echo PROXY_HTTP=$_PROXY_HTTP >$HOME/.zsh.conf/custom.zsh

chsh -s $(which zsh)

#### starship
ln -svf $dotfilespath/zsh/starship/starship.toml $HOME/.config/starship.toml
# starship will be installed in zshrc.
# sh -c "$(curl -fsSL https://starship.rs/install.sh)"

### utils
git clone https://github.com/wg/wrk.git $tools/wrk
cd $tools/wrk
sudo make
sudo cp wrk /usr/local/bin

# install stylua(https://github.com/JohnnyMorganz/StyLua)

git clone https://github.com/universal-ctags/ctags.git $tools/ctags
cd $tools/ctags
./autogen.sh
./configure # --prefix=/where/you/want defaults to /usr/local
make
sudo make install

source $HOME/.zshrc
update_go
update_lua
update_nvim
update_nodejs

# change the timezone
# sudo ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
