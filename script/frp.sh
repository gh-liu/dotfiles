install_frp() {
	repo="fatedier/frp"
	url="https://api.github.com/repos/$repo/tags"
	version=$(eval "curl -s $url | jq -r '.[0].name'")

	file="frp_${version:1}_linux_amd64.tar.gz"
	downloadurl="https://github.com/fatedier/frp/releases/download/$version/$file"
	wget $downloadurl -q --show-progres
	test $? -eq 1 && echo "fial to download" && return

	tar -zxvf $file
	mv frp_${version:1}_linux_amd64 frp
	cd frp

	mkdir -p /usr/local/bin
	mkdir -p /usr/local/etc/frp
	sudo ln -svf $(pwd)/frps /usr/local/bin/frps
	sudo ln -svf $(pwd)/frpc /usr/local/bin/frpc
	sudo ln -svf $(pwd)/frps.ini /usr/local/etc/frp/frps.ini
	sudo ln -svf $(pwd)/frpc.ini /usr/local/etc/frp/frpc.ini
}

setup_frpc() {
	echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Unit]
Description = frp client
After = network.target
Wants = network.target

[Service]
ExecStart=/usr/local/bin/frpc -c /usr/local/etc/frp/frpc.ini
RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target" > \
		'/etc/systemd/system/frpc.service'
}

setup_frps() {
	echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Unit]
Description = frp server
After = network.target
Wants = network.target

[Service]
ExecStart=/usr/local/bin/frps -c /usr/local/etc/frp/frps.ini
RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target" > \
		'/etc/systemd/system/frps.service'

	systemctl start frps
	systemctl enable frps
}
