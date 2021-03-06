#!/bin/sh
# Making the base system, partions, and as well as moving into chroot

#Constants
hostname=beryllium
user=taha
bootdrive=/dev/sdb
rootdrive=/dev/sda
rootdriveP=/dev/sda1    #NVME has an extra p

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
partprobe $rootdrive
wipefs -af $rootdriveP


#Setting up Boot usb key
mkfs.fat -F32 -n ESP $bootdrive"1"
mkdir /tmp/efiboot
mount -v -t vfat $bootdrive"1" /tmp/efiboot
    #Making the key
export GPG_TTY=$(tty)
#8Mib
#8kib   idk if this will work
#dd if=/dev/urandom bs=8192 count=1 | gpg --symmetric --cipher-algo AES256 --output /tmp/efiboot/key.gpg
#dd if=/dev/urandom bs=8388607 count=1 | gpg --symmetric --cipher-algo AES256 --output /tmp/efiboot/key.gpg
dd if=/dev/urandom bs=8388 count=1 | gpg --symmetric --cipher-algo AES256 --output /tmp/efiboot/key.gpg


# EMPTY DRIVE
#dd if=/dev/urandom of=$rootdriveP bs=1M status=progress && sync


# Encrypting Root drive
echo RELOADAGENT | gpg-connect-agent
    #encrypgint
gpg --decrypt /tmp/efiboot/key.gpg | cryptsetup --cipher serpent-xts-plain64 --key-size 512 --hash whirlpool --key-file - luksFormat $rootdriveP
    #header backup
cryptsetup luksHeaderBackup $rootdriveP --header-backup-file /tmp/efiboot/header.img 
    #opening
gpg --decrypt /tmp/efiboot/key.gpg | cryptsetup --key-file - luksOpen $rootdriveP root
mkfs.btrfs -q -L ROOT /dev/mapper/root
umount /tmp/efiboot     #unmounting boot


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
mount -v -t vfat -o nodev,nosuid,noexec $bootdrive"1" /mnt/boot
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@snap /dev/mapper/root /mnt/.snap
    # USER
mkdir /mnt/home/taha
mount -o noatime,ssd,nodiscard,nosuid,noexec,nodev,compress=zstd:3,subvol=@taha /dev/mapper/root /mnt/home/taha
mkdir /mnt/home/taha/{devel,sys,.cache,.tmp}
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
pacstrap /mnt base linux-hardened linux-firmware intel-ucode zsh sudo nano neovim ranger
genfstab -U /mnt >> /mnt/etc/fstab

# new files
cp gpgcryptHook     /mnt/lib/initcpio/hooks/gpgcrypt
cp gpgcryptInstall  /mnt/lib/initcpio/install/gpgcrypt
cp arch_2.sh /mnt
arch-chroot /mnt /bin/bash
