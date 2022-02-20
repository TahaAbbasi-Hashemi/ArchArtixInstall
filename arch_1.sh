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
sgdisk --new 2:::   --typecode 2:8300 --change-name 2:"SUB" "$bootdrive"
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


#Making the BTRFS subsystem
echo RELOADAGENT | gpg-connect-agent
gpg --decrypt /tmp/efiboot/key.gpg | cryptsetup --key-file - luksOpen $bootdriveP root
mkfs.btrfs -q -L ROOT /dev/mapper/root
mount /dev/mapper/root /mnt
btrfs su cr /mnt/@          #General Root
btrfs su cr /mnt/@etc       #Root system config, and defaults
btrfs su cr /mnt/@var       #Mail
btrfs su cr /mnt/@var_log   #Logs
btrfs su cr /mnt/@opt       #Matlab
btrfs su cr /mnt/@snap      #Backups, snapshots
btrfs su cr /mnt/@usr       #less compression, all binaries.
btrfs su cr /mnt/@srv       #Personal Website
    #User sub system
btrfs su cr /mnt/@taha          #General stuff in home folder, doenst get backed up with snaps
btrfs su cr /mnt/@taha_config   #All program config.
btrfs su cr /mnt/@taha_devel    #I want this backed up often
btrfs su cr /mnt/@taha_down     #Downloads folder, no datacow
btrfs su cr /mnt/@taha_media    #Media-> Movies, books, pictures, music
btrfs su cr /mnt/@taha_local    #System config-> GTK theme, icons, fonts, custom programs(neofetch)
#btrfs su cr /mnt/@taha_bin      #Custom neofetch, this is inside of .local
btrfs su cr /mnt/@taha_research #My research -> experiments, papers, other work.
btrfs su cr /mnt/@taha_work     #Work files (manufactoring, tutoring, pay stubs)
btrfs su cr /mnt/@taha_school   #Files related to school, past labs, etc
btrfs su cr /mnt/@taha_person   #Bank files, resumes, copies of important files related to me.
#Person should be encrypted to protect from bad programs.
umount /mnt


#Runtime are light compressed (bin, usr)        level 1
#change often are moderate compressed. (var)    level 3
#low change are heavy compressed (etc, config)  level 6
#noatime -> reduce writes
#ssd -> ssd optimization
#nodiscard -> remove trim.
#compress -> compression
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@ /dev/mapper/sys /mnt
    #Top level folders
mkdir /mnt/{boot,etc,home,opt,srv,usr,var,.snap}
#mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@etc /dev/mapper/sys /mnt/etc
mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@opt /dev/mapper/sys /mnt/opt
mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@srv /dev/mapper/sys /mnt/srv
#mount -o noatime,ssd,nodiscard,compress=zstd:1,subvol=@usr /dev/mapper/sys /mnt/usr
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@var /dev/mapper/sys /mnt/var
mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@snap /dev/mapper/sys /mnt/.snap
    #Sub level 1.
mkdir /mnt/var/log
mkdir /mnt/home/taha
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@var_log /dev/mapper/sys /mnt/var/log
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@taha /dev/mapper/sys /mnt/home/taha
    #Sub level 2
mkdir /mnt/home/taha/{.config,.local,devel,down,media,research,work,school,person}
mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@taha_config /dev/mapper/sys /mnt/home/taha/.config
mount -o noatime,ssd,nodiscard,compress=zstd:1,subvol=@taha_local /dev/mapper/sys /mnt/home/taha/.local
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@taha_devel /dev/mapper/sys /mnt/home/taha/devel
mount -o noatime,ssd,nodiscard,nodatadow,compress=zstd:3,subvol=@taha_down /dev/mapper/sys /mnt/home/taha/down
mount -o noatime,ssd,nodiscard,compress=zstd:3,subvol=@taha_media /dev/mapper/sys /mnt/home/taha/media
mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@taha_research /dev/mapper/sys /mnt/home/taha/research
mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@taha_work /dev/mapper/sys /mnt/home/taha/work
mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@taha_school /dev/mapper/sys /mnt/home/taha/school
mount -o noatime,ssd,nodiscard,compress=zstd:6,subvol=@taha_person /dev/mapper/sys /mnt/home/taha/person
    #Boot mounting
mount $bootdrive /mnt/boot
    #Swap file
truncate -s 0 /mnt/.swapfile
chattr +C /mnt/.swapfile
btrfs property set /mnt/.swapfile compression none
dd if=/dev/zero of=/mnt/.swapfile bs=1G count=5 status=progress && sync
chmod 600 /mnt/.swapfile
mkswap /mnt/.swapfile
swapon /mnt/.swapfile


#Making ghe base system
pacstrap /mnt base linux-hardened linux-firmware intel-ucode zsh doas nano nvim ranger
genfstab -U /mnt >> /mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab
echo "tmpfs	/home/taha/tmp	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab
echo "tmpfs	/home/taha/.cache	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab

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
