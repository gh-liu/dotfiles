#!/bin/sh
default() {
    export http_proxy="${PROXY_HTTP}"
    export HTTP_PROXY="${PROXY_HTTP}"

    export https_proxy="${PROXY_HTTP}"
    export HTTPS_proxy="${PROXY_HTTP}"
}
default

set_proxy() {
    default
    echo "set proxy to $PROXY_HTTP"
}
unset_proxy() {
    unset http_proxy
    unset HTTP_PROXY
    unset https_proxy
    unset HTTPS_PROXY

    echo "unset proxy"
}
