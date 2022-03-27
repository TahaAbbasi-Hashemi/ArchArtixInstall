#!/bin/sh
# User system configurations for new arch install

#Constants
hostname=beryllium
user=taha

# Config 
mkdir /home/taha/.config
pacman -Syu git
git clone https://github.com/TahaAbbasi-Hashemi/dotfiles /home/taha/.config

# System Binaries
git clone https://github.com/TahaAbbasi-Hashemi/systembinaries /home/taha/bin

# Meta Packages
# Thesis/Disertation Programming
# Thesis/Disertation Writiting



