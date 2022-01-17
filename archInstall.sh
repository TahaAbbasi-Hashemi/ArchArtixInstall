#!/bin/sh

#Constants
drive=sda
driveP=sda3
hostname=beryllium
host=root
wifiP=password
wifiU=username


#Installing none essential software for basic opperation
pacman -S --noconfirm nano dhcpcd zsh neofetch


#Language time, etc.
ln -sf /urs/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf
echo $hostname >> /etc/hostname
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hostname".localdomain "$hostname >> /etc/hosts
chsh -s /bin/zsh


#internet stuff
touch /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$wifiU'\n    psk='$wifiP'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
systemctl enable dhcpcd@eth0.service

#Root Passwords
echo "ROOT PASSWORD"
passwd


#mkinitcpio
echo -e "MODULES=()\nBINARIES=()\nFILES=()\nHOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)\n" > /etc/mkinitcpio.conf
mkinitcpio -p linux-hardened


#Bootloader
mkdir /boot/loader
mkdir /boot/loader/entries
touch /boot/loader/loader.conf
touch /boot/loader/entries/"$hostname".conf


#Boot drive
UUID=$(lsblk -o NAME,UUID | grep "$driveP" | awk '{print $2}')
echo -e 'title '$hostname'_hardened \nlinux /vmlinuz-linux-hardened \ninitrd /initramfs-linux-hardened.img \noptions cryptdevice=UUID='$UUID':cryptlvm:allow-discards root=/dev/systemgroup/root rw loglevel=3' >> /boot/loader/entries/"$hostname".conf
echo -e "timeout 25\nconsole-mode max\neditor no" >> /boot/loader/loader.conf

systemd-machine-id-setup
bootctl --path=/boot install











