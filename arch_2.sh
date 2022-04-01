#!/bin/sh
# System Configuration for dual factor authentication

#Constants
hostname=beryllium
user=taha

# TMPFS
mkdir /home/taha/.cache
mkdir /home/taha/.tmp
mkdir /tmp
echo "tmpfs /tmp                tmpfs   rw,nosuid,noatime,nodev 0 0" >> /etc/fstab
echo "tmpfs /home/taha/.cache   tmpfs   rw,nosuid,noatime,nodev 0 0" >> /etc/fstab
echo "tmpfs /home/taha/.tmp     tmpfs   rw,nosuid,noatime,nodev 0 0" >> /etc/fstab
mount -a

# REFLECTOR and PACMAN
pacman -S reflector
reflector --country Canada --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Rns reflector
sed -i 's/#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf
sed -i 's/#Color/Color/g' /etc/pacman.conf
pacman -S dash zsh ranger neovim

# GPG
#cd /tmp
#pacman -S --asdeps base-devel
#curl -OL https://gnupg.org/ftp/gcrypt/gnupg/gnupg-1.4.23.tar.bz2
#tar xjf gnupg-1.4.23.tar.bz2
#cd gnupg-1.4.23
#CC=gcc LDFLAGS=-static CFLAGS="-g0 -fcommon" ./configure
#make && make install

# MKINITCPIO
sed -i "s/modconf block/modconf block fsck shutdown encrypt gpgcrypt/g" /etc/mkinitcpio.conf
sed -i "s/MODULES=()/MODULES=(btrfs vfat)/g" /etc/mkinitcpio.conf
sed -i "s/BINARIES=()/BINARIES=(\/usr\/local\/bin\/gpg)/g" /etc/mkinitcpio.conf
#sed -i "s/FILES=()/FILES=(\/boot\/key.gpg)/g" /etc/mkinitcpio.conf
mkinitcpio -P

# TIME
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc

# Locale and language
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo "LANG=en_US.UTF-8\nLANGUAGE=en_US\nLC_ALL=c" >> /etc/locale.conf
locale-gen

# HOST
echo "beryllium" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 beryllium.localdomain beryllium" >> /etc/hosts

# SH
ln -sfT dash /usr/bin/sh
chsh -s /bin/zsh

# Usernames and Passwords
echo "ROOT PASSWORD"
passwd
useradd -M -g users -G wheel -s /usr/bin/zsh taha
passwd taha
    

#Systemd boot
usb1=$(ls -l /dev/disk/by-id | awk '/sdb1/{print $9}')
uuid=$(lsblk -o NAME,UUID | awk '/sda1/{print $2}')
mkdir /boot/EFI
mkdir /boot/loader
mkdir /boot/loader/entries
echo "timeout 15" >> /boot/loader/loader.conf
echo "console-mode max" >> /boot/loader/loader.conf
echo "title Arch Linux" >> /boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux-hardened" >> /boot/loader/entries/arch.conf
echo "initrd /intel-ucode.img" >> /boot/loader/entries/arch.conf
echo "initrd /initramfs-linux-hardened.img" >> /boot/loader/entries/arch.conf
echo "options root=/dev/mapper/root cryptdevice=UUID=$uuid:root cryptkey=/dev/by-id/$usb1:vfat:/key.gpg rw loglevel=3 intel_iommu=on rootflates=subvol=@beryllium" >> /boot/loader/entries/arch.conf
bootctl --esp-path=/boot install


#Enabling things with systemctl
#systemctl enable dhcpcd
