#!/bin/sh



#Names
un=taha
cn=lvmsys
vn=sys
hn=beryllium
up=qw
cp=qw
rp=qw


#System Configuration
dri=/dev/sda #drive
pen=1
pbn=2
psn=3
pes=+512M
pbs=+512M
pss=:
pe=$dri"$pen" #add a p if using nvme
pb=$dri"$pbn" #add a p if using nvme
ps=$dri"$psn" #add a p if using nvme


#Error checking
set -e


#Partions
pacman -S --noconfirm gptfdisk parted #artix only
sgdisk --zap-all $dri
sgdisk --mbrtogpt $dri
sgdisk --new $pen::$pes --typecode $pen:ef00 --change-name $pen:"EFI" $dri
sgdisk --new $pbn::$pbs --typecode $pbn:ef00 --change-name $pbn:"BOOT" $dri
sgdisk --new $psn::$pss --typecode $psn:8304 --change-name $psn:"SYS" $dri
partprobe $dri
wipefs -af $pe
wipefs -af $pb
wipefs -af $ps


#Encrypting
modprobe dm_crypt
modprobe dm_mod
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 luksFormat $ps
cryptsetup open $ps $cn
pvcreate /dev/mapper/$cn
vgcreate $vn /dev/mapper/$cn
lvcreate -L 1G $vn -n etc
lvcreate -L 1G $vn -n swap
lvcreate -L 1G $vn -n home
lvcreate -L 1G $vn -n snap
lvcreate -L 2G $vn -n root
lvcreate -L 9G $vn -n var
lvcreate -L 9G $vn -n usr

vgchange -a n
cryptsetup close $cn
cryptsetup open $ps $cn


#Formatting
mkfs.fat -F32 -n BOOT $pb
mkswap /dev/mapper/$vn-swap
swapon /dev/mapper/$vn-swap
mkfs.btrfs -q -L ROOT /dev/mapper/$vn-root
mount o noatime,compress=zstd:2 /dev/mapper/$vn-root /mnt
drives="etc var usr home snap"
for i in {0..4}
do
    lower=$(awk '{print $'$i'}' -e $dri)
    upper=$(echo $lower | tr "[:lower:]" "[:upper:]")
    mkfs.btrfs -q -L $upper /dev/mapper/$vn-$lower
    mkdir /mnt/$lower
    mount -o noatime,compress=zstd:2 /dev/mapper/$vn-$lower /mnt/$lower
done
mkdir /mnt/boot
mount $pb /mnt/boot

lsblk 
fdisk -l
sleep 10






#closing
swapoff -a
vgchange -a n
cryptsetup close $cn








