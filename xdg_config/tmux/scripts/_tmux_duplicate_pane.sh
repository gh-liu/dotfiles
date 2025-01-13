#!/bin/bash
set -e

# https://superuser.com/questions/1739803/is-it-possible-to-create-a-new-pane-with-the-same-connection-in-tmux
pid="$(tmux display-message -p '#{pane_pid}')"
pid="$(ps -o tpgid:1= -p "$pid")"
dir="$(readlink -f "/proc/$pid/cwd")"
cd -- "${dir:?}"
exe="$(readlink -f "/proc/$pid/exe")"
readarray -d '' args <"/proc/$pid/cmdline"
name="${args[0]}"
args=("${args[@]:1}")

tmux split-window "$@" -c "$dir" bash -c "exec -a ${name@Q} ${exe@Q} ${args[*]@Q}"
