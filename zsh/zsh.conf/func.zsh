#!/bin/sh
# Open your $EDITOR in the lower 3rd of your tmux window until you exit it.
peek() { tmux split-window -p 33 "$EDITOR" "$@" }

# https://www.commandlinefu.com/commands/view/9065/what-is-the-use-of-this-switch-
function manswitch () { man $1 | less -p "^ +$2"; }

# proxy set and unset
# set_proxy(){
#     PROXY_HTTP=http://127.0.0.1:1081

#     export http_proxy="${PROXY_HTTP}"
#     export HTTP_PROXY="${PROXY_HTTP}"

#     export https_proxy="${PROXY_HTTP}"
#     export HTTPS_proxy="${PROXY_HTTP}"
# }
# set_proxy
# unset_proxy(){
#     unset http_proxy
#     unset HTTP_PROXY
#     unset https_proxy
#     unset HTTPS_PROXY
# }
