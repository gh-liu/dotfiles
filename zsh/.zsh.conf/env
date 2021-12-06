#!/bin/sh
export OS=`echo \`uname\` | tr '[:upper:]' '[:lower:]'`

# $EDITOR
if command -v nvim &> /dev/null
then
    export EDITOR=nvim
else
    export EDITOR=vim
fi

export TERM="screen-256color"

export HOSTIP=$(hostname -I | awk '{print $1}')

# go env
export GO111MODULE=on
#export GOPROXY=direct
# export GOPROXY=https://goproxy.io,https://proxy.golang.org,direct
# export GOSUMDB=gosum.io+ce6e7565+AY5qEHUk/qmHc5btzW45JVoENfazw8LielDsaI+lEbq6
export GOPATH=~/env/golang/gopath
export GOBIN=$GOPATH/bin
export GOROOT=~/env/golang/go
# export PATH=$PATH:$GOBIN:$GOROOT/bin/
# export GOPRIVATE=

# node env
export NODE_HOME=~/env/nodejs/node

# java env
export JAVA_HOME=~/env/java/jdk
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar

# docker
export DOCKER_DATA=~/env/docker/data
export DOCKER_CONF=~/env/docker/conf

# vagrant
export VGHOME=~/env/vm

# vagrant
export TMUXP=~/.tmuxp

export NOTES_DIR=~/mynotes

path=(
    $HOME/bin
    $GOPATH/bin                              # golang
    $GOROOT/bin
    $JAVA_HOME/bin                           # java
    $NODE_HOME/bin                           # nodejs
    $HOME/.local/bin                         # pipx
    $path
  )
export PATH=":$PATH"

export tools=~/tools
