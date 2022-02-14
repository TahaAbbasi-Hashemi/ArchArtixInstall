#!/bin/sh

#Constants
mdrive=/dev/sda
bd=/dev/sda1
md=/dev/sda2

cn=cryptroot
hn=beryllium
user=taha


#Partions
pacman -S --noconfirm gptfdisk parted #artix only
sgdisk --zap-all $mdrive
sgdisk --mbrtogpt $mdrive
sgdisk --new 1::+1G --typecode 1:ef00 --change-name 1:"BOOT" $mdrive
sgdisk --new 2:::   --typecode 2:8304 --change-name 2:"ROOT" $mdrive
partprobe $mdrive
wipefs -af $bd
wipefs -af $md


#Encrypting 
modprobe dm_mod
cryptsetup -v --type luks luksFormat $md
cryptsetup open $md $cn


#Formatting and mounting
mkfs.fat -F32 -n ESP $bd
mkfs.btrfs -q -L ROOT /dev/mapper/$cn

#Making subvols
subvols="etc srv opt var varlog usr snap home"
mount /dev/mapper/$cn /mnt
btrfs su cr /mnt/@
for i in {1..8}
do 
    lower=$(echo $subvols | awk '{print $'$i'}')
    btrfs su cr /mnt/@$lower
done
umount /mnt

#Mounting subvols
mount -o noatime,ssd,compress=zstd:4,space_cache,subvol=@ /dev/mapper/$cn /mnt
mkdir /mnt/{usr,srv,etc,var,snap,home,opt}
#This is commented to see if usr is what is causing all the prolems
mount -o noatime,ssd,compress=zstd:1,space_cache,passno=2,subvol=@usr /dev/mapper/$cn /mnt/usr
mount -o noatime,ssd,compress=zstd:5,space_cache,subvol=@etc /dev/mapper/$cn /mnt/etc
mount -o noatime,ssd,compress=zstd:5,space_cache,subvol=@opt /dev/mapper/$cn /mnt/opt
#mount -o noatime,ssd,compress=zstd:5,space_cache,subvol=@snap /dev/mapper/$cn /mnt/snap
mount -o noatime,ssd,compress=zstd:5,space_cache,subvol=@var /dev/mapper/$cn /mnt/var
#mount -o noatime,ssd,compress=zstd:5,space_cache,subvol=@srv /dev/mapper/$cn /mnt/srv
mount -o noatime,ssd,compress=zstd:2,space_cache,subvol=@home /dev/mapper/$cn /mnt/home
mkdir /mnt/var/log
mkdir /mnt/boot
#mount -o noatime,ssd,compress=zstd:5,space_cache,subvol=@varlog /dev/mapper/$cn /mnt/var/log
mount $bd /mnt/boot



#Entering the new system
basestrap /mnt base openrc elogind-openrc
basestrap /mnt linux-hardened linux-hardened-headers linux-firmware
basestrap /mnt grub btrfs-progs cryptsetup-openrc efibootmgr
basestrap /mnt haveged-openrc cronie-openrc dhcpcd-openrc artix-archlinux-support apparmor-openrc firewalld-openrc
basestrap /mnt zsh dash nano neofetch sudo doas

#Making swap
truncate -s 0 /mnt/swapfile
chattr +C /mnt/swapfile
btrfs property set /mnt/swapfile compression none
dd if=/dev/zero of=/mnt/swapfile bs=1G count=5 status=progress
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile


#File system and Pacman Modifications
#pacman -S --noconfirm reflector
fstabgen -p -U /mnt >> /mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab  #ram drive for /tmp
sed -i 's/#ParallelDownloads/ParallelDownloads/g' /mnt/etc/pacman.conf      #Pacman packages
echo -e "[extra]\nInclude = /etc/pacman.d/mirrorlist-arch \n\n[community]\nInclude = /etc/pacman.d/mirrorlist-arch \n\n[multilib]\nInclude = /etc/pacman.d/mirrorlist-arch\n" >> /mnt/etc/pacman.conf
artix-chroot /mnt pacman -Sy
artix-chroot /mnt pacman-key --populate archlinux
#reflector --country Canada --age 12 --sort rate --save /mnt/etc/pacman.d/mirrorlist
#reflector --country Canada --age 12 --sort rate --save /mnt/etc/pacman.d/mirrorlist-arch


#Timezone, locale, and hosts/hostname 
ln -sf /usr/share/zoneinfo/America/Toronto /mnt/etc/localtime               
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen       
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /mnt/etc/locale.conf
echo $hn >> /mnt/etc/hostname                                     
echo "127.0.0.1 localhost" > /mnt/etc/hosts
echo "::1 localhost" > /mnt/etc/hosts
echo "127.0.1.1 $hn.localdomain $hn" > /mnt/etc/hosts
artix-chroot /mnt hwclock --systohc
artix-chroot /mnt bash <<- EOF
		locale-gen
EOF
    

#Users, sudo/doas, shell
#basestrap -i /mnt sudo doas
echo "permit $user as root" > /mnt/etc/doas.conf
sed -i "s/# %wheel ALL=(ALL) ALL/wheel ALL=(ALL) ALL/g" /mnt/etc/sudoers
#artix-chroot /mnt ln -sfT dash /usr/bin/sh


#LUKS and mkinitcpio configuration
sed -i "s/modconf block/modconf block usr fsck shutdown encrypt/g" /mnt/etc/mkinitcpio.conf  
sed -i "s/MODULES=()/MODULES=(btrfs)/g" /mnt/etc/mkinitcpio.conf
#mkinitcpio -P
    

#Grub
sysUUID=$(blkid -s UUID -o value $md)
sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$sysUUID:$cn root=\/dev\/mapper\/$cn rootflags=subvol=@ rw\"/g" /mnt/etc/default/grub
sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /mnt/etc/default/grub
sed -i 's/#GRUB_DISABLE_SUB_MENU=y/GRUB_DISABLE_SUB_MENU=y/g' /mnt/etc/default/grub
#echo 'GRUB_DISABLE_OS_PROBER=false' >> /mnt/etc/default/grub
mkdir /mnt/boot/efi
artix-chroot /mnt mkinitcpio -P
artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

artix-chroot /mnt /bin/bash
