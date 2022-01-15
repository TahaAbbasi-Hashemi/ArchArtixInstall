#!/bin/sh

#Constants
driveP=/dev/sda5
hostname=subsys
hostname2=SubSys
wifiP=password
wifiU=username


#Installing none essential software for basic opperation
pacman -S --noconfirm nano doas wpa_supplicant dhcpcd zsh


#Language time, etc.
ln -sf /urs/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf
echo $hostname >> /etc/hostname
chsh -s /bin/zsh


#internet stuff
pacman -S --noconfirm wpa_supplicant dhcpcd
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hostname".localdomain "$hostname >> /etc/hosts
mkdir /etc/wpa_supplicant
touch /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$wifiU'\n    psk='$wifiP'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
#systemctl enable dhcpcd@eth0.service


#Passwords
echo "ROOT PASSWORD"
passwd
useradd -m -g users -G wheel "$username"
passwd $username


#mkinitcpio
echo -e "MODULES=()\nBINARIES=()\nFILES=()\nHOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)\n" > /etc/mkinitcpio.conf
mkinitcpio -p


#Bootloader
touch /boot/loader/entries/"$hostname2".conf
UUID=$(lsblk -o NAME,UUID | grep "$driveP" | awk '{print $2}')
echo -e "title "$hostname"_linuxhardened\n linux /vmlinuz-linux-hardened\ninitrd /initramfs-linux-hardened.img\n options cryptdevice=UUID="$UUID":"$hostname":allow-discards root=/dev/mapper/"$hostname" rw loglevel=3" > /boot/loader/entries/"$hostname".conf
