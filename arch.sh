# [install arch](https://wiki.archlinux.org/title/Installation_guide)
# 1. 准备安装映像， 使用启动盘进入Live环境
# 2. 磁盘分区、格式化、挂载
# 2.1 分区:  查看所有硬盘`fdisk -l`; 对制定的硬盘进行分区`fdisk /dev/sda`，`g`创建GPT分区，`n`创建新分区随后输入大小(大小记得乘以2)，`t`修改分区类型(需要如下分区: 1. efi分区 2.系统/分区 而 3.swap分区 4./home分区按需设置(home不设置则在/分区生成))
# 2.2 格式化:  mkfs.ext4 /dev/root_partition（根分区）； mkswap /dev/swap_partition（交换空间分区）
# 2.3 挂载:  mount /dev/root_partition（根分区） /mnt； swapon /dev/swap_partition（交换空间分区）
# 3. 连接网络、修改软件源、安装基本系统
# 3.1 todo
# 3.2 `vim /etc/pacman.d/mirrorlist`， 添加`Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch`
# 3.3 `pacstrap /mnt base base-devel linux linux-firmware`
# 4. 配置安装的系统
# 4.1 生成fstab, 记录自动挂载分区的信息:  `genfstab -U /mnt >> /mnt/etc/fstab`
# 4.2 Chroot，改变根目录，到挂载的/mnt，也就是你将新安装的系统根目录: `arch-chroot /mnt`
# 4.3 设置时区, `ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime` `hwclock --systohc`
# 4.4 本地化, `vim /etc/locale.gen`, 取消掉 en_US.UTF-8 UTF-8 和其他需要的 地区 前的注释（#）, 执行`locale-gen`; `vim /etc/locale.conf`添加`LANG=en_US.UTF-8`
# 4.5 设置密码:  `passwd`
# 5. 安装引导程序
# 5.1 首先安装软件包 grub 和 efibootmgr: `sudo pacman -S grub efibootmgr`
# 5.2 挂载 EFI 系统分区，把后面的esp 替换成挂载点: `grub-install --target=x86_64-efi --efi-directory=esp --bootloader-id=GRUB`
# 5.3 生成 grub.cfg: `grub-mkconfig -o /boot/grub/grub.cfg`
# 5.4 按 Ctrl+d 退出 chroot 环境
# 6. 重启，成功进入系统

# install & configurate i3

# chinese input


echo -e "\n" | sudo pacman -S archlinuxcn-keyring
echo -e "\n" | sudo pacman -S yay

echo -e "\n" | sudo pacman -S base-devel coreutils
echo -e "\n" | sudo pacman -S zsh vim tmux tmuxp alacritty
echo -e "\n" | sudo pacman -S jq bat fzf ctags ripgrep the_silver_searcher proxychains-ng 
echo -e "\n" | sudo pacman -S docker docker-compose 
echo -e "\n" | sudo pacman -S htop tcpdump strace perf httpie wrk cmake gdb lldb 
echo -e "\n" | sudo pacman -S virtualbox vagrant 
echo -e "\n" | sudo pacman -S cloc github-cli neofetch cmatrix
echo -e "\n" | sudo pacman -S bash-language-server nodejs npm
echo -e "\n" | sudo pacman -S graphviz namcap
echo -e "\n" | sudo pacman -S vlc spotify google-chrome obsidian visual-studio-code-insiders-bin typora telegram-desktop nomacs

yay -S direnv wechat-uos