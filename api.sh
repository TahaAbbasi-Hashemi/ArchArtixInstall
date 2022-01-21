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
cryptsetup -v --iter-time 5000 --type luks2 -s 512 --hash sha512 luksFormat $ps
cryptsetup open $ps $cn
cryptsetup close $cn
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
vgchange -a y


#Formatting
mkfs.fat -F32 -n EFI $pe
mkfs.ext4 -L BOOT $pb
mkswap /dev/mapper/$vn-swap
swapon /dev/mapper/$vn-swap
mkfs.btrfs -q -L ROOT /dev/mapper/$vn-root
mount -o noatime,compress=zstd:2 /dev/mapper/$vn-root /mnt
for i in {1..5}
do
    lower=$(echo "etc var usr home snap" | awk '{print $'$i'}')
    upper=$(echo $lower | tr "[:lower:]" "[:upper:]")
    mkfs.btrfs -q -L $upper /dev/mapper/$vn-$lower
    mkdir /mnt/$lower
    mount -o noatime,compress=zstd:2 /dev/mapper/$vn-$lower /mnt/$lower
done
mkdir /mnt/boot
mount $pb /mnt/boot
mkdir /mnt/boot/efi
mount $pe /mnt/boot/efi
#lsblk


#Entering the new system
basestrap -i /mnt base elogind-runit
basestrap -i /mnt linux-zen linux-zen-headers linux-hardened linux-hardened-headers linux-firmware
basestrap -i /mnt grub btrfs-progs cryptsetup lvm2
basestrap -i /mnt haveged-runit cronie-runit dhcpcd-runit artix-archlinux-support
basestrap -i /mnt zsh dash nano neofetch sudo


#File system and pacman modifications
fstabgen -p -U /mnt > /mnt/etc/fstab
echo "tmpfs /tmp tmpfs rw,nosuid,noatime,nodev 0 0" >> /mnt/etc/fstab
sed -i 's/#ParallelDownloads/ParallelDownloads/g' /mnt/etc/pacman.conf      #Pacman packages
echo -e "[extra]\nInclude = /etc/pacman.d/mirrorlist-arch \n\n[community]\nInclude = /etc/pacman.d/mirrorlist-arch \n\n[multilib]\nInclude = /etc/pacman.d/mirrorlist-arch\n" >> /mnt/etc/pacman.conf


#Timezone, locale, and hosts/hostname
ln -sf /usr/share/zoneinfo/America/Toronto /mnt/etc/localtime
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /mnt/etc/locale.conf
echo $hn >> /mnt/etc/hostname
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hn".localdomain "$hn >> /mnt/etc/hosts


#Users, sudo/doas, shell
echo "permit $un as root" > /mnt/etc/doas.conf
sed -i "s/# %wheel ALL=(ALL) ALL/wheel ALL=(ALL) ALL/g" /etc/sudoers


#LUKS and mkinitcpio configuration
sed -i "s/modconf block/keyboard keymap consolefont modconf block encrypt lvm2/g" /mnt/etc/mkinitcpio.conf
dd if=/dev/random of=/mnt/root/crypto.keyfile bs=512 count=8 iflag=fullblock
chmod 000 /mnt/root/crypto.keyfile
sed -i "s/FILES=(/FILES=(\/root\/crypto.keyfile/g" /mnt/etc/mkinitcpio.conf
cryptsetup luksAddKey $ps /mnt/root/crypto.keyfile


basestarp /mnt efibootmgr
artix-chroot /mnt bash <<- EOF
    hwclock --systohc
    locale-gen
    pacman -Syu
    pacman -S --asdeps --noconfirm efibootmgr dosfstools freetype2 fuse2 gptdisk libisoburn mtools os-prober
    pacman-key --populate archlinux
    ln -sfT dash /usr/bin/sh
    mkinitcpio -v -P
    grub-install --efi-directory=/boot/efi --target=x86_64-efi --bootloader-id=GRUB
EOF

#Editing GRUB
sysUUID=$(blkid -s UUID -o value $ps)
sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$sysUUID:$vn root=/dev/mapper/$vn cryptkey=rootfs:\/root\/crypto.keyfile\"/g" /mnt/etc/default/grub
sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /mnt/etc/default/grub
#sed -i 's/#GRUB_DISABLE_SUB_MENU=y/GRUB_DISABLE_SUB_MENU=y/g' /mnt/etc/default/grub
echo 'GRUB_DISABLE_OS_PROBER=false' >> /mnt/etc/default/grub
artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
artic-chroot /mnt grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg

echo "We got here now"
sleep 10


#closing
#umount -R /mnt
#swapoff -a
#vgchange -a n
#cryptsetup close $cn







