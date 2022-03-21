#!/bin/sh
#Installs arch linux with its boot drive on a USB and its main system on a nvmessd

#Constants
hostname=beryllium
user=taha


bootdrive=/dev/sda
rootdrive=/dev/sdb
rootdriveP=/dev/sdb1    #NVME has an extra p

modprobe dm_mod

#Partions
    #Boot
sgdisk --zap-all "$bootdrive"
sgdisk --mbrtogpt "$bootdrive"
sgdisk --new 1::+1G --typecode 1:ef00 --change-name 1:"ESP" "$bootdrive"
sgdisk --new 2:::   --typecode 2:8300 --change-name 2:"USB" "$bootdrive"
partprobe $bootdrive
wipefs -af $bootdrive"1"
wipefs -af $bootdrive"2"
    #Root
sgdisk --zap-all "$rootdrive"
sgdisk --mbrtogpt "$bootdrive"
sgdisk --new 1::: --typecode 1:8304 --change-name 1:"SYS" "$rootdrive"
partprobe $bootdrive
wipefs -af $rootdriveP


#Setting up Boot usb key
mkfs.fat -F32 -n ESP $bootdrive"1"
mkdir /tmp/efiboot
mount -v -t vfat $bootdrive"1" /tmp/efiboot
    #Making the key
export GPG_TTY=$(tty)
dd if=/dev/urandom bs=8388607 count=1 | gpg --symmetric --cipher-algo AES256 --output /tmp/efiboot/key.gpg


#Encrypting The Root Partion
    #Fill with random data. Will take a long time
#dd if=/dev/urandom of=$rootdriveP bs=1M status=progress && sync
echo RELOADAGENT | gpg-connect-agent
gpg --decrypt /tmp/efiboot/key.gpg | cryptsetup --cipher serpent-xts-plain64 --key-size 512 --hash whirlpool --key-file - luksFormat $bootdriveP
cryptsetup luksHeaderBackup $bootdriveP --header-backup-file /tmp/efiboot/header.img 


#Opening the drive for read and write plus setting as btrfs
echo RELOADAGENT | gpg-connect-agent
gpg --decrypt /tmp/efiboot/key.gpg | cryptsetup --key-file - luksOpen $bootdriveP root
mkfs.btrfs -q -L ROOT /dev/mapper/root


#Making subvols
mount /dev/mapper/root /mnt
    #ROOT
btrfs su cr /mnt/@beryllium #General Root, exec
btrfs su cr /mnt/@snap      #Backups, snapshots, no exec
    #USER
btrfs su cr /mnt/@taha          #no execution
btrfs su cr /mnt/@taha_devel    #Allow execution
btrfs su cr /mnt/@taha_sys      #Allow execution (system config stuff)
umount /mnt


# Mounting
# Beryllium, Gallium
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@beryllium /dev/mapper/root /mnt
    # ROOT
mkdir /mnt/{boot,media,.snap,home}
mount -o nodev,nosuid,noexec $bootdrive /mnt/boot
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@opt /dev/mapper/root /mnt/opt
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@snap /dev/mapper/root /mnt/.snap
    # USER
mkdir /mnt/home/taha
mkdir /mnt/home/taha/{devel,sys,.cache,.tmp}
mount -o noatime,ssd,nodiscard,nosuid,noexec,nodev,compress=zstd:3,subvol=@taha /dev/mapper/root /mnt/home/taha
mount -o noatime,ssd,nodiscard,compress=zstd:1,subvol=@taha_devel /dev/mapper/root /mnt/home/taha/devel
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@taha_sys /dev/mapper/root /mnt/home/taha/sys
    # SWAP
truncate -s 0 /mnt/.swapfile
chattr +C /mnt/.swapfile
btrfs property set /mnt/.swapfile compression none
dd if=/dev/zero of=/mnt/.swapfile bs=1G count=5 status=progress && sync
chmod 600 /mnt/.swapfile
mkswap /mnt/.swapfile
swapon /mnt/.swapfile


#Base packages and FSTAB
pacstrap /mnt base linux-hardened linux-firmware intel-ucode zsh doas nano nvim ranger
genfstab -U /mnt >> /mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab
echo "tmpfs	/home/taha/.cache	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab
echo "tmpfs	/home/taha/.tmp	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab 

#Pacman Optimizations
sed -i 's/#ParallelDownloads/ParallelDownloads/g' /mnt/etc/pacman.conf      #Pacman packages
reflector --country Canada --age 12 --sort rate --save /mnt/etc/pacman.d/mirrorlist


#Timezone, locale, and hosts/hostname 
ln -sf /usr/share/zoneinfo/America/Toronto /mnt/etc/localtime               
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen       
echo "LANG=en_US.UTF-8\nLANGUAGE=en_US\nLC_ALL=c" >> /mnt/etc/locale.conf
echo $hostname >> /mnt/etc/hostname                                     
echo "127.0.0.1 localhost" > /mnt/etc/hosts
echo "::1 localhost" > /mnt/etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" > /mnt/etc/hosts
    

#Users, sudo/doas, shell
echo "permit $user as root" > /mnt/etc/doas.conf
sed -i "s/# %wheel ALL=(ALL) ALL/wheel ALL=(ALL) ALL/g" /mnt/etc/sudoers


#LUKS and mkinitcpio configuration
sed -i "s/modconf block/modconf block usr fsck shutdown encrypt/g" /mnt/etc/mkinitcpio.conf  
sed -i "s/MODULES=()/MODULES=(btrfs)/g" /mnt/etc/mkinitcpio.conf
   
cp arch_2.sh /mnt
arch-chroot /mnt /bin/bash
