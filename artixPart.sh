#!/bin/sh


#Constants
drive=/dev/sda
driveP=$drive #For a nvme
cryptname=lvmsys
cn=$cryptname
volname=sys
hostname=beryllium
hn=$hostname
user=taha


#System Configuration
#p-> partion
#e-> efi
#b-> boot
#s-> sys
dri=/dev/sda
pen=1
psn=2
prn=3

pes=+512M
pss=+2G
prs=:

pe=$dri$pen #add a p if using nvme
ps=$dri$psn #add a p if using nvme
pr=$dri$prn #add a p if using nvme


#Error checking
set -e


#Checking if the system has UEFI
if [-z "$(ls /sys/firmware/efi)"] 
then 
    echo "NO EFI"
    exit
fi


#Partions
pacman -S --noconfirm gptfdisk parted #artix only
sgdisk --zap-all "$dri"
sgdisk --mbrtogpt "$dri"
sgdisk --new $pen::$pes --typecode $pen:ef00 --change-name $pen:"ESP" "$dri"
sgdisk --new $psn::$pss --typecode $psn:8200 --change-name $psn:"SWAP" "$dri"
sgdisk --new $prn::$prs --typecode $prn:8304 --change-name $prn:"ROOT" "$dri"
partprobe $dri
wipefs -af $pe
wipefs -af $ps
wipefs -af $pr


#Encrypting 
modprobe dm_mod
cryptsetup -v --type luks luksFormat $pr
cryptsetup open $pr $cn


#Formatting and mounting
mkfs.fat -F32 -n ESP $pe
mkfs.btrfs -q -L ROOT /dev/mapper/$cn

#Making subvols
subvols="etc opt var varlog usr rootsnap home homesnap homedownloads homeconfig"
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
mkdir /mnt/{usr,etc,var,snap,home,opt}
mkdir /mnt/var/log
mkdir /mnt/home/{config,downloads,snap}
mount -o noatime,ssd,compress=zstd:1,space_cache,subvol=@usr /dev/mapper/$cn /mnt/usr
mount -o noatime,ssd,compress=zstd:4,space_cache,subvol=@etc /dev/mapper/$cn /mnt/etc
mount -o noatime,ssd,compress=zstd:4,space_cache,subvol=@var /dev/mapper/$cn /mnt/var
mount -o noatime,ssd,compress=zstd:4,space_cache,subvol=@opt /dev/mapper/$cn /mnt/opt
#mount -o noatime,ssd,compress=zstd:4,space_cache,subvol=@varlog /dev/mapper/$cn /mnt/var/log
mount -o noatime,ssd,compress=zstd:4,space_cache,subvol=@rootsnap /dev/mapper/$cn /mnt/snap
mount -o noatime,ssd,compress=zstd:2,space_cache,subvol=@home /dev/mapper/$cn /mnt/home
#mount -o noatime,ssd,compress=zstd:4,space_cache,subvol=@homesnap /dev/mapper/$cn /mnt/home/snap
#mount -o noatime,ssd,compress=zstd:4,nodatcow,space_cache,subvol=@homedownloads /dev/mapper/$cn /mnt/home/downloads
#mount -o noatime,ssd,compress=zstd:4,space_cache,subvol=@homeconfig /dev/mapper/$cn /mnt/home/config
mkdir /mnt/boot
mount $pe /mnt/boot


#Saving the system
#pacstrap -i /mnt base linux-zen linux-hardened linux-firmware intel-ucode btrfs-progs
#genfstab -U /mnt >> /mnt/etc/fstab

#Entering the new system
basestrap -i /mnt base
basestrap /mnt linux-hardened linux-hardened-headers linux-firmware
basestrap /mnt grub btrfs-progs cryptsetup-runit efibootmgr
basestrap /mnt haveged-runit cronie-runit dhcpcd-runit artix-archlinux-support
basestrap /mnt zsh dash nano neofetch sudo




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
basestrap -i /mnt sudo doas
echo "permit $user as root" > /mnt/etc/doas.conf
sed -i "s/# %wheel ALL=(ALL) ALL/wheel ALL=(ALL) ALL/g" /mnt/etc/sudoers
#artix-chroot /mnt ln -sfT dash /usr/bin/sh


#LUKS and mkinitcpio configuration
sed -i "s/modconf block/modconf block encrypt/g" /mnt/etc/mkinitcpio.conf  
sed -i "s/MODULES=()/MODULES=(btrfs)/g" /mnt/etc/mkinitcpio.conf
#mkinitcpio -P
    

#Grub
sysUUID=$(blkid -s UUID -o value $pr)
sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$sysUUID:$cn root=\/dev\/mapper\/$cn\"/g" /mnt/etc/default/grub
sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /mnt/etc/default/grub
sed -i 's/#GRUB_DISABLE_SUB_MENU=y/GRUB_DISABLE_SUB_MENU=y/g' /mnt/etc/default/grub
#echo 'GRUB_DISABLE_OS_PROBER=false' >> /mnt/etc/default/grub
mkdir /mnt/boot/efi
artix-chroot /mnt mkinitcpio -P
artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg


artix-chroot /mnt /bin/bash
