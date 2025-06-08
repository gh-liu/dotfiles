#!/bin/bash
commands=$(grep -r --exclude="install.sh" --exclude=".nvim.lua" "@need-install:" . | sed 's/.*@need-install: //' | sort | uniq)

echo "Install: "
echo "========"
echo "$commands"
echo "========"

read -rp "install? (y/n): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "$commands" | while IFS= read -r cmd; do
                echo "exec: $cmd"
                eval "$cmd"
        done
fi
