#!/bin/sh

#Constants
driveP=/dev/sda3
hostname=bootsys
wifiP=password
wifiU=username


#Installing none essential software for basic opperation
pacman -S --noconfirm nano doas wpa_supplicant dhcpcd zsh snapper neofetch


#Language time, etc.
ln -sf /urs/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf
echo $hostname >> /etc/hostname
chsh -s /bin/zsh


#internet stuff
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hostname".localdomain "$hostname >> /etc/hosts
#mkdir /etc/wpa_supplicant
touch /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$wifiU'\n    psk='$wifiP'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
systemctl enable dhcpcd@eth0.service

#Root Passwords
echo "ROOT PASSWORD"
passwd


#mkinitcpio
echo -e "MODULES=()\nBINARIES=()\nFILES=()\nHOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)\n" > /etc/mkinitcpio.conf
mkinitcpio -p


#Bootloader
mkdir /boot/loader
mkdir /boot/loader/entries
touch /boot/loader/loader.conf
touch /boot/loader/entries/"$hostname".conf
UUID=$(lsblk -o NAME,UUID | grep "$driveP" | awk '{print $2}')
echo -e "title "$hostname"_linux\n linux /vmlinuz-linux\ninitrd /initramfs-linux.img\n options root="$UUID" rw loglevel=3" > /boot/loader/entries/"$hostname".conf
echo -e "timeout 5\nconsole-mode max\neditor no" >> /boot/loader/loader.conf

systemd-machine-id-setup
bootctl --path=/boot install


cat /boot/loader/entries/arch.conf










