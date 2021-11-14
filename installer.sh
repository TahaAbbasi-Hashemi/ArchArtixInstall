#!/bin/sh


DRIVE=/dev/nvme0n1
hostname=mainSystem #CAN THIS BE UPPERCASE???
username=taha #MUST BE LOWERCASE
WIFI_PASSWORD=password
WIFI_USERNAME=username

#Installing none essential software for basic opperation
pacman -S --noconfirm nano doas wpa_supplicant dhcpcd zsh

#Language time, etc.
ln -sf /urs/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc -utc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf
echo $hostname >> /etc/hostname
chsh -s /bin/zsh

#internet stuff
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts
mkdir /etc/wpa_supplicant
touch /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$WIFI_USERNAME'\n    psk='$WIFI_PASSWORD'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf

#Users and passwords
passwd
useradd -m -g users -G wheel "$username"
passwd "$username"
touch /etc/doas.conf
echo "permit wheel as root" > /etc/doas.conf

#Editing FSTAB
echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab
echo "tmpfs /home/$username/.cache tmpfs defaults,noatime 0 0" >> /etc/fstab

#mkinitcpio
echo -e "MODULES=()\nBINARIES=()\nFILES=()\HOOKT=(base udev autodetect modconf block encrypt filesystems keyboard fsck)\n" > /etc/mkinitcpio.conf
mkinitcpio -p linux-zen

#Bootloader
mkdir /boot/loader
mkdir /boot/loader/entries
touch /boot/loader/loader.conf
touch /boot/loader/entries/artix.conf

UUID3=(blkid -s UUID -o value "$DRIVE"3)
echo -e 'title ArchLinux\n linux /vmlinuz-linux-zen\ninitrd /intel-ucode.img\ninitrd /initamfs-linux-zen.img\noptions cryptdevice=UUID=$UUID3:cryptroot root=/dev/mapper/MainSystem rw intel_iommu=on loglevel=3' > /boot/loader/entries/arch.conf
echo -e "default arch.conf\ntimeout 5\nconsole-mode max\neditor no" >> /boot/loader/loader.conf

bootctl --path=/boot install

#ON artix linux need to compile systemd boot first.





