#!/bin/bash

mkdir -p /usr/local/bin/xray
mkdir -p /usr/local/etc/xray

sudo ln -svf $(pwd)/xray /usr/local/bin/xray
sudo ln -svf $(pwd)/config.json /usr/local/etc/xray/config.json
sudo cp $(pwd)/xray.service /etc/systemd/system/xray.service

systemctl start xray

export ALL_PROXY="http://127.0.0.1:1080"
