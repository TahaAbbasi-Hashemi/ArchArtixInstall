#!/bin/sh


#Constants
drive=/dev/sda
driveP=$drive #For a nvme
cryptname=lvmsys
volname=sys
hostname=beryllium
user=taha


#System Configuration
#p-> partion
#e-> efi
#b-> boot
#s-> sys
pen=1
pbn=2
psn=3

pes=+512M
pbs=+512M
pss=:

pe=$drive$pen #add a p if using nvme
pb=$drive$pbn #add a p if using nvme
ps=$drive$psn #add a p if using nvme


#Error checking
set -e


#Checking if the system has UEFI
if [-z "$(ls /sys/firmware/efi)"] then 
    echo "NO EFI"
    exit
fi


#Partions
pacman -S --noconfirm gptfdisk parted #artix only
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"
sgdisk --new $pen::$pes --typecode $pen:ef00 --change-name $pen:"EFI" "$drive"
sgdisk --new $pbn::$pbs --typecode $pbn:ef00 --change-name $pbn:"BOOT" "$drive"
sgdisk --new $psn::$pss --typecode $psn:8304 --change-name $psn:"SYS" "$drive"
partprobe $drive #Saves
wipefs -af $pe
wipefs -af $pb
wipefs -af $ps

