#!/bin/sh


DRIVE=/dev/nvme0n1
hostname=mainSystem #CAN THIS BE UPPERCASE???
username=taha #MUST BE LOWERCASE
WIFI_PASSWORD=password
WIFI_USERNAME=username

#Clearing Current System
sgdisk --zap-all "$DRIVE"
sgdisk --mbrtogpt "$DRIVE"

#Making Drives (Change size in real run)
sgdisk --new 1::+512M --typecode 1:ef00 --change-name 1:"EFI-Boot" "$DRIVE"
sgdisk --new 2::+500M --typecode 2:8200 --change-name 1:"System-Swap" "$DRIVE"
sgdisk --new 3::+12G --typecode 3:8300 --change-name 3:"Main-System" "$DRIVE"
sgdisk --new 4::+500M --typecode 4:8304 --change-name 4:"Sub-System" "$DRIVE"
sgdisk --new 5::+500M --typecode 5:8304 --change-name 5:"Spare-System" "$DRIVE"
sgdisk --new 6::: --typecode 6:8300 --change-name 6:"Home-Storage" "$DRIVE"

#Wiping Drives
wipefs -af "$DRIVE"1
wipefs -af "$DRIVE"2
wipefs -af "$DRIVE"3
wipefs -af "$DRIVE"4
wipefs -af "$DRIVE"5
wipefs -af "$DRIVE"6

#Only encrypt what arch uses. Gentoo can read home??
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$DRIVE"3
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$DRIVE"6

#Opening System
cryptsetup open "$DRIVE"3 mainSystem
cryptsetup open "$DRIVE"6 homePartion

#Formatting
mkfs.vfat "$DRIVE"1
mkswap "$DRIVE"2
swapon "$DRIVE"2
mkfs.btrfs /dev/mapper/mainSystem 
mkfr.btrfs /dev/mapper/homePartion

#Setting up btrfs partions
#Can this even work??
#mount /dev/mapper/homePartion /mnt
#btrfs su cr /mnt/@
#btrfs su cr /mnt/@configuration
#btrfs su cr /mnt/@documents
#btrfs su cr /mnt/@development
#btrfs su cr /mnt/@research
#btrfs su cr /mnt/@school
#btrfs su cr /mnt/@teaching
#btrfs su cr /mnt/@.snapshots
#umount /mnt

#Mounting
mount -0 noatime,nodiratime,compress=zstd:2 /dev/mapper/mainSystem /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount -0 noatime,nodiratime,compress=zstd:4 /dev/mapper/homePartion /mnt/home #Setup snaps for the home directory....
#Can this even work?
#mkdir /mnt/home/Taha
#mkdir /mnt/home/Taha/configuration
#mkdir /mnt/home/Taha/documents
#mkdir /mnt/home/Taha/development
#mkdir /mnt/home/Taha/research
#mkdir /mnt/home/Taha/school
#mkdir /mnt/home/Taha/teaching
#mkdir /mnt/home/Taha/.snapshots

#mount -0 noatime,nodiratime,compress=zstd:4,space_cache=v2,subvol=@configuration /dev/mapper/homePartion /mnt/home/Taha/configuration
#mount -0 noatime,nodiratime,compress=zstd:4,space_cache=v2,subvol=@documents /dev/mapper/homePartion /mnt/home/Taha/documents
#mount -0 noatime,nodiratime,compress=zstd:4,space_cache=v2,subvol=@developments /dev/mapper/homePartion /mnt/home/Taha/development
#mount -0 noatime,nodiratime,compress=zstd:4,space_cache=v2,subvol=@research /dev/mapper/homePartion /mnt/home/Taha/research
#mount -0 noatime,nodiratime,compress=zstd:4,space_cache=v2,subvol=@school /dev/mapper/homePartion /mnt/home/Taha/school
#mount -0 noatime,nodiratime,compress=zstd:4,space_cache=v2,subvol=@teaching /dev/mapper/homePartion /mnt/home/Taha/teaching
#mount -0 noatime,nodiratime,compress=zstd:4,space_cache=v2,subvol=@snapshots /dev/mapper/homePartion /mnt/home/Taha/snapshots

#nmcli device connect USERMAME password $WIFI_PASSWORD
pacstrap /mnt base linux-zen linux-firmware intel-ucode 
genfstab -U /mnt > /mnt/etc/fstab

arch-chroot /mnt /bin/bash #This allows me to use the script??
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

UUID3=(blkid -s UUID -o value "$DRIVE"3
echo -e "title ArchLinux\n linux /vmlinuz-linux-zen\ninitrd /intel-ucode.img\ninitrd /initamfs-linux-zen.img\noptions cryptdevice=UUID=$UUID3:cryptroot root=/dev/mapper/MainSystem rw intel_iommu=on loglevel=3" > /boot/loader/entries/arch.conf
echo -e "default arch.conf\ntimeout 5\nconsole-mode max\neditor no" >> /boot/loader/loader.conf

bootctl --path=/boot install

#ON artix linux need to compile systemd boot first.





