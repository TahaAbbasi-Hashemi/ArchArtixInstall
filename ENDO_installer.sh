#!/bin/sh

#Constants
hostname=main #CAN THIS BE UPPERCASE???
username=endo


#Installing none essential software for basic opperation
pacman -S --noconfirm plasma kde-applications kde-utilities kde-education kde-graphics kde-games kde-system kde-pim kdesdk kde-accessibility kde-network sddm pulseaudio vtk eigen cmake utf8cpp unzip liblas fmt code cura boost alacritty freecad jdk11-openjdk libreoffice-fresh pavucontrol qbittorrent zathura zip firefox git base-devel grub efibootmgr networkmanager nm-connection-editor network-manager-applet nano doas zsh sudo


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
systemctl enable NetworkManager.service


#Root Passwords
echo "ROOT PASSWORD"
passwd


#User Password
useradd -m -g users -G wheel "$username"
passwd "$username"


#Let user be root.
touch /etc/doas.conf
echo "perit "$username" as root" > /etc/doas.conf


#Editing FSTAB
echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab


#mkinitcpio
echo -e "MODULES=(btrfs)\nBINARIES=()\nFILES=()\nHOOKS=(base udev autodetect modconf block filesystems keyboard fsck)\n" > /etc/mkinitcpio.conf
mkinitcpio -p

#Installing Grub
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg


systemctl enable sddm

git clone https://TahaAbbasi-Hashemi/EndovascularSurgery


echo "YOU NEED TO EDIT SUDOERS YOURSELF TO LET YOU BE ROOT"











