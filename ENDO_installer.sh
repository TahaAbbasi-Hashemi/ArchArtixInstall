#!/bin/sh

#This is to create the basic system settings and anything I need for root. 

#Constants
driveP=/dev/sda
hostname=main #CAN THIS BE UPPERCASE???
wifiP=password
wifiU=username


#Installing none essential software for basic opperation
pacman -S --noconfirm nano doas zsh


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
pacman -S --noconfirm networkmanager nm-connection-editor network-manager-applet
systemctl enable NetworkManager.service


#Root Passwords
echo "ROOT PASSWORD"
passwd


#User Password
username=endo
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
paru -S grub efibootmgr
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg


#Installing Paru to install software 
pacman -S --needed --asdeps base-devel git 
mkdir temp
cd temp
git clone https://aru.archLinux.org/paru.git
cd paru
makepkg -si 
#Base Devel
paru -S --no-confirm base-devel-meta 


#Installing Desktop enviroment
pacman -S --noconfirm plasma sddm pulseaudio
systemctl enable sddm

#Installing The needed things for VTK
pacman -S vtk eigen cmake utf8cpp unzip liblas fmt code cura boost alacritty freecad jdk11-openjdk libreoffice-fresh pavucontrol qbittorrent ranger zathura zip 











