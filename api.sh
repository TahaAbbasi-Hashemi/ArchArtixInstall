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
pe=$drive"$pen" #add a p if using nvme
pb=$drive"$pbn" #add a p if using nvme
ps=$drive"$psn" #add a p if using nvme


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
#cryptsetup -v --type luks2 -h sha512 luksFormat $ps
echo -n $cp | cryptsetup -v -M luks2 -h sha512 luksFormat $llvm
echo -n $cp | cryptsetup open $ps $cn
pvcreate /dev/mapper/$cn
vgcreate $vn /dev/mapper/$cn
lvcreate -L 1G $vn -n etc
lvcreate -L 1G $vn -n swap
lvcreate -L 1G $vn -n home
lvcreate -L 1G $vn -n snap
lvcreate -L 2G $vn -n root
lvcreate -L 9G $vn -n var
lvcreate -L 9G $vn -n var
vgscan
vgchange -ay


#Formatting








