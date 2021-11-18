#!/bin/sh

#This is to create the basic system settings and anything I need for root. 

#Constants
driveP=/dev/sda
hostname=main #CAN THIS BE UPPERCASE???
wifiP=password
wifiU=username


#Installing none essential software for basic opperation
pacman -S --noconfirm nano doas wpa_supplicant dhcpcd zsh snapper


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
mkdir /etc/wpa_supplicant
touch /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$wifiU'\n    psk='$wifiP'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf


#Root Passwords
echo "ROOT PASSWORD"
passwd


#Editing FSTAB
echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab


#mkinitcpio
echo -e "MODULES=(btrfs)\nBINARIES=()\nFILES=()\nHOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)\n" > /etc/mkinitcpio.conf
mkinitcpio -p


#Bootloader
mkdir /boot/loader
mkdir /boot/loader/entries
touch /boot/loader/loader.conf
touch /boot/loader/entries/arch.conf
UUID3=$(blkid -s UUID -o value "$driveP"3)
echo -e "title ArchLinux\n linux /vmlinuz-linux-zen\ninitrd /initramfs-linux-zen.img\n options cryptdevice=UUID="$UUID3":mainSystem:allow-discards root=/dev/mapper/mainSystem rw loglevel=3" > /boot/loader/entries/arch.conf
echo -e "default arch.conf\ntimeout 5\nconsole-mode max\neditor no" >> /boot/loader/loader.conf

#mounting of the homepartion
touch /etc/crypttab
UUID6=$(blkid -s UUID -o value "$driveP"6)
echo "homePartion "$UUID6" none timeout180"


#Installing Paru to install software 
pacman -S --needed --asdeps base-devel git 
mkdir temp
cd temp
git clone https://aru.archLinux.org/paru.git
cd paru
makepkg -si 
#Base Devel
paru -S --no-confirm base-devel-meta 
#Artix Only
#paru -S --no-confirm nosystemd-boot


#Installing Boot Loader
bootctl --path=/boot install
#Set up pacman-hook as well

#Allow wifi on next reboot. 
systemctl enable dhcpcd@eth0.service













