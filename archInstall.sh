#!/bin/sh

#LAST RUN ERROR
#blkid -t not used. (seen after grub interface)

#Constants
drive=/dev/sda
driveP=$driveP  #This is for nvme
user=taha
volname=sys
cryptname=lvmsys
hostname=beryllium
wifiPass=password
wifiUser=username


#Installing none essential software for basic opperation
pacman -S --noconfirm nano dhcpcd zsh neofetch lvm2 haveged-runit cronie-runit dhcpcd-runit
pacman -S cryptsetup lvm2 #For MKINITCPIO


#Language time, etc.
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf
echo $hostname >> /etc/hostname
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hostname".localdomain "$hostname >> /etc/hosts
chsh -s /bin/zsh


#INTERNET STUFF
#wpa_passphrase "$wifeUser" "$wifiPass" > /etc/wpa_supplicant/wpa_supplicant.conf
#echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$wifiU'\n    psk='$wifiP'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
ln -s /etc/runit/sv/dhcpcd /run/runit/service


#Passwords and Users
echo "ROOT PASSWORD"
passwd
useradd -m -G wheel -s /bin/zsh $user
passwd $user
sed -i "s/# %wheel ALL=(ALL) ALL/wheel ALL=(ALL) ALL/g" /etc/sudoers


#mkinitcpio
#echo -e "MODULES=()\nBINARIES=()\nFILES=()\nHOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)\n" > /etc/mkinitcpio.conf
sed -i "s/modconf block/keyboard keymap consolefont modconf block encrypt lvm2/g" /etc/mkinitcpio.conf
dd if=/dev/random of=/crypto_keyfile.bin bs=512 count=8 iflag=fullblock
chmod 000 /crypto_keyfile.bin
sed -i "s/FILES=(/FILES=(\/crypto_keyfile.bin/g" /etc/mkinitcpio.conf
cryptsetup luksAddKey /dev/sda2 /crypto_keyfile.bin
mkinitcpio -p linux-hardened
sleep 10


#GRUB
pacman -S grub 
pacman -S --asdeps efibootmgr dosfstools freetype2 fuse2 gptfdisk libisoburn mtools os-prober
sysUUID=$(blkid -s UUID -o value $driveP"2")
sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$sysUUID:$cryptname cryptkey=rootfs:\/crypto_keyfile.bin\"/g" /etc/default/grub #I think something wrong with this line. I am not sure. 
sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=$hostname --recheck $drive
grub-mkconfig -o /boot/grub/grub.cfg
sleep 10
    #Adding Features for encryption
ln -s /etc/runit/sv/cronie /run/runit/service
ln -s /etc/runit/sv/haveged /run/runit/service

exit



