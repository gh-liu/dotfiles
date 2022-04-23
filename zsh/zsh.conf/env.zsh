#!/bin/sh
# You may need to manually set your language environment
export LANG=en_US.UTF-8
export TERM="screen-256color"
export DISABLE_AUTO_TITLE='true'

export OS=`echo \`uname\` | tr '[:upper:]' '[:lower:]'`
export HOSTIP=$(hostname -I | awk '{print $1}')

export tools=$HOME/tools


# $EDITOR
if command -v nvim &> /dev/null
then
    export EDITOR=nvim
else
    export EDITOR=vim
fi

# golang env
export GO111MODULE=on
#export GOPROXY=direct
# export GOPROXY=https://goproxy.io,https://proxy.golang.org,direct
# export GOSUMDB=gosum.io+ce6e7565+AY5qEHUk/qmHc5btzW45JVoENfazw8LielDsaI+lEbq6

export GOROOT=$DEV_ENV/golang/go
export GOPATH=$DEV_ENV/golang/gopath
export GOBIN=$GOPATH/bin
# export GOPRIVATE=
export PATH=$PATH:$GOBIN:$GOROOT/bin/


# rust
# curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
export RUSTUP_HOME=$DEV_ENV/rust/rustup
export CARGO_HOME=$DEV_ENV/rust/cargo
# export PATH=$PATH:$HOME/.cargo/bin


# node env
export NODE_HOME=$DEV_ENV/nodejs/node
export PATH=$PATH:$NODE_HOME/bin


# java env
export JAVA_HOME=$DEV_ENV/java/jdk
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export PATH=$PATH:$JAVA_HOME/bin 

# docker
export DOCKER_DATA=$DEV_ENV/docker/data
export DOCKER_CONF=$DEV_ENV/docker/conf


# vagrant
export VGHOME=$DEV_ENV/vm


export PATH=$PATH:$HOME/bin:$HOME/.local/bin

# Remove duplicate env var
export PATH=$(echo $PATH | tr : "\n"| sort | uniq | tr "\n" :)

