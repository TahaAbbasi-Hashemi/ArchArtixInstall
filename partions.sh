#!/bin/sh

#Constants
drive=/dev/sda
driveP=/dev/sda
mainSysName=mainSystem
hostname=mainsystem
username=taha
wifiP=password
wifiU=username


#Clearing Current System
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"
sgdisk --new 1::+512M   --typecode 1:ef00 --change-name 1:"EFI-Boot" "$drive"       #Change to 1gb
sgdisk --new 2::+500M   --typecode 2:8200 --change-name 2:"System-Swap" "$drive"    #Change to 30gb
sgdisk --new 3::+12G    --typecode 3:8304 --change-name 3:"Main-System" "$drive"    #Change to 50gb
sgdisk --new 4::+500M   --typecode 4:8304 --change-name 4:"Sub-System" "$drive"     #Change to 50gb
sgdisk --new 5::+500M   --typecode 5:8304 --change-name 5:"Spare-System" "$drive"   #Change to 50gb
sgdisk --new 6:::       --typecode 6:8300 --change-name 6:"Home-Storage" "$drive"
partprobe $DRIVE #Saves
wipefs -af "$driveP"1
wipefs -af "$driveP"2
wipefs -af "$driveP"3
wipefs -af "$driveP"4
wipefs -af "$driveP"5
wipefs -af "$driveP"6


#Encrypting
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"3
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"6
cryptsetup open "$driveP"3 mainSystem
cryptsetup open "$driveP"6 homePartion


#Formatting
mkfs.fat -F32 -n LIUNXEFI "$driveP"1
mkswap "$driveP"2
swapon "$driveP"2
mkfs.btrfs -L MainSystem /dev/mapper/mainSystem 
mkfs.btrfs -L HomePartion /dev/mapper/homePartion
#mkfs.btrfs -L HomePartion "$driveP"6


#BTRFS subsystems
mount /dev/mapper/homePartion /mnt
btrfs subvolume create /mnt/@development
btrfs subvolume create /mnt/@configuration
btrfs subvolume create /mnt/@teaching
btrfs subvolume create /mnt/@school
btrfs subvolume create /mnt/@research
btrfs subvolume create /mnt/@documents
umount /mnt


#Mounting
mount -o noatime,nodiratime,compress=zstd:2 /dev/mapper/mainSystem /mnt
mkdir /mnt/boot
mkdir /mnt/home
mkdir /mnt/home/{development,configuration,teaching,school,research,documents}
mount "$driveP"1 /mnt/boot
mount -o noatime,nodiratime,compress=zstd:4,subvol=@home            /dev/mapper/homePartion /mnt/home
mount -o noatime,nodiratime,compress=zstd:4,subvol=@development     /dev/mapper/homePartion /mnt/home/development
mount -o noatime,nodiratime,compress=zstd:4,subvol=@configuration   /dev/mapper/homePartion /mnt/home/configuration
mount -o noatime,nodiratime,compress=zstd:4,subvol=@teaching        /dev/mapper/homePartion /mnt/home/teaching
mount -o noatime,nodiratime,compress=zstd:4,subvol=@school          /dev/mapper/homePartion /mnt/home/school
mount -o noatime,nodiratime,compress=zstd:4,subvol=@research        /dev/mapper/homePartion /mnt/home/research
mount -o noatime,nodiratime,compress=zstd:4,subvol=@documents       /dev/mapper/homePartion /mnt/home/documents


#Entering the new system
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware intel-ucode 
#pacstrap /mnt base openrc elogid-openrc linux-zen linux-zen-headers linux-firmware intel-ucode 

genfstab -U /mnt > /mnt/etc/fstab


#Getting ready for stage two
cp installer.sh /mnt
cp user.sh /mnt
arch-chroot /mnt
#artix-chroot /mnt


#Basic configuration
pacman -S --noconfirm nano doas wpa_supplicant dhcpcd zsh snapper


#Language time, etc.
ln -sf /urs/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf #Move this to .zsh
echo $hostname >> /etc/hostname
chsh -s /bin/zsh

echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hostname".localdomain "$hostname >> /etc/hosts
mkdir /etc/wpa_supplicant
touch /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$wifiU'\n    psk='$wifiP'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf

#Passwords
echo "ROOT PASSWORD"
passwd
useradd -m -g users -G wheel "$username"
passwd "$username"

#Boot loader
pacman -S --nocomfirm grub
pacman -S --asdeps os-prober efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg
