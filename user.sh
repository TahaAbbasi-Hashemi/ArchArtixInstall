#!/bin/sh

#This file is for user modifications. This enables programs, home and other things the user might need. 

#Making user and their password
username=taha
useradd -m -g users -G wheel "$username"
passwd "$username"

#Let user be root. 
touch /etc/doas.conf
echo "perit "$username" as root" > /etc/doas.conf

#Edit FSTAB
mkdir "/home/"$username"/.cache"
echo "tmpfs /home/"$username"/.cache tmpfs defaults,noatime 0 0" >> /etc/fstab

#Using Snapper to make subpartions
snapper -c home create-config --fstype btrfs /home
snapper -c development create-config --fstype btrfs /home/development
snapper -c configuration create-config --fstype btrfs /home/configuration

#Make the default saves. 
snapper -c home create -d basic
snapper -c development create -d basic
snapper -c configuration create -d basic  
