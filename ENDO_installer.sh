#!/bin/sh

#Constants
hostname=main #CAN THIS BE UPPERCASE???
username=endo

#Language time, etc.
ln -sf /urs/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf
echo $hostname >> /etc/hostname
chsh -s /bin/zsh

echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hostname".localdomain "$hostname >> /etc/hosts

#Passwords
echo "ROOT PASSWORD"
passwd
useradd -m -g users -G wheel "$username"
passwd "$username"

#Installation
pacman -S --noconfirm plasma kde-applications kde-utilities kde-education kde-graphics kde-games kde-system kde-pim kdesdk kde-accessibility kde-network sddm pulseaudio vtk eigen cmake utf8cpp unzip liblas fmt code cura boost alacritty freecad jdk11-openjdk libreoffice-fresh pavucontrol qbittorrent zathura zip firefox git base-devel grub efibootmgr networkmanager nm-connection-editor network-manager-applet nano doas zsh sudo gnuplot graphviz python python-mpi4py python-matplotlib openmpi qt5-x11extras qt5-webkit tk adios2 cgns ffmpeg gdal gl2ps glew hdf5 jsoncpp libarchive libharu liblas lz4 netcdf openimagedenoise openvdb openvr ospray pdal postgresql pugixml proj sqlite unixodbc 

#Enabling software
systemctl enable NetworkManager.service
systemctl enable sddm


#mkinitcpio
echo -e "MODULES=(btrfs)\nBINARIES=()\nFILES=()\nHOOKS=(base udev autodetect modconf block filesystems keyboard fsck)\n" > /etc/mkinitcpio.conf
mkinitcpio -p linux-zen

#Installing Grub
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg



echo "\n\n\n\n\n\n\n"
echo "YOU NEED TO EDIT SUDOERS YOURSELF TO LET YOU BE ROOT\n"
echo "run the next line\n"
echo "EDITOR=nano visudo"
echo "Find where it says 'root ALL=(ALL) ALL' and under that line add this \n"
echo "endo ALL=(ALL) ALL\n"











