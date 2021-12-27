#!/bin/sh

#Constants
drive=/dev/sda
driveP=/dev/sda
mainSysName=mainSystem
hostname=mainsystem
username=taha
wifiP=password
wifiU=username


#Basic configuration
pacman -S --noconfirm nano doas snapper zsh wpa_supplicant dhcpcd grub connman-runit
pacman -S --noconfirm --asdeps os-prober efibootmgr
#Language time, etc.
ln -sf /urs/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf #Move this to .zsh
echo $hostname >> /etc/hostname
#Shell
chsh -s /bin/zsh
#Internet
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hostname".localdomain "$hostname >> /etc/hosts
#mkdir /etc/wpa_supplicant
#touch /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
#echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$wifiU'\n    psk='$wifiP'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
#cp -r /etc/runit/sv/dhcpcd /etc/runit/sv/dhcpcd-enp3s0 #Runnit
#Passwords
echo "ROOT PASSWORD"
passwd
useradd -m -g users -G wheel "$username"
passwd "$username"

#IDK TRY CONNMAN
ln -s /etc/runit/sv/connmand /etc/runit/runsvdir/default

#Boot loader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

#Make sure sudo is installed.
#exit
#reboot now

