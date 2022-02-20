#!/bin/sh
#Installs arch linux with its boot drive on a USB and its main system on a nvmessd

#Constants
user=taha
bootdrive=/dev/sda
rootdrive=/dev/sdb
rootdriveP=/dev/sdb1    #NVME has an extra p


hwclock --systhoc
locale-gen
ln -sfT dash /usr/bin/sh
mkinitcpio -P
chsh -s /bin/zsh
echo "ROOT PASSWORD"
passwd
useradd -M -g users -G wheel taha
passwd taha
    

#Systemd boot
sysUUID=$(lsblk -o NAME,UUID | grep $rootdriveP | awk '{print $2}')
mkdir /boot/EFI
mkdir /boot/loader
mkdir /boot/loader/entries
echo "timeout 15" >> /boot/loader/loader.conf
echo "console-mode max" >> /boot/loader/loader.conf
echo "title Arch Linux" >> /boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux-hardened" >> /boot/loader/entries/arch.conf
echo "initrd /intel-ucode.img" >> /boot/loader/entries/arch.conf
echo "initrd /inramfs-linux-hardened.img" >> /boot/loader/entries/arch.conf
echo "options cryptdevice=UUID=$sysUUID:root root=/dev/mapper/root rw intel_iommu=on rootflates=subvol=@ loglevel=3 lsm=landlock,yama,apparnor,buf" >> /boot/loader/entries/arch.conf
bootctl --esp-path=/boot/EFI --boot-path=/boot install


#Enabling things with systemctl
#systemctl enable dhcpcd
