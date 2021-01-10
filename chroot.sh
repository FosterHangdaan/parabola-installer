#!/usr/bin/env bash

cd $(dirname $0)
source settings.cfg

# Set hostname
sed "s|HOSTNAME|${HOSTNAME}|" etc/hosts.txt >> /etc/hosts
if [[ $INIT_SYSTEM == 'systemd' ]]; then
	echo $HOSTNAME > /etc/hostname
else
	echo "hostname=$HOSTNAME" > /etc/conf.d/hostname
fi

# Set locales and keymap
sed "s|LANG_VAR|$LCLANG|; s|TIME_VAR|$LCTIME|" etc/locale.conf > /etc/locale.conf
sed -i "s|^#$LCLANG|$LCLANG|; s|^#$LCTIME|$LCTIME|" /etc/locale.gen
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Set timezone
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime

# Generate locales
locale-gen

# Setup bootloader and kernel for encryption if any
CRYPTDEVICES=$(lsblk -o 'FSTYPE' | grep -c 'crypt')
if [[ $CRYPTDEVICES -ge 1 ]]; then
	CRYPTUUID=$(lsblk -o 'NAME,FSTYPE,UUID' | grep "$BLKDEV" | grep 'crypto_LUKS' | awk '{print $3}')
	sed -i "s|^HOOKS=\(.*\)|HOOKS=\(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck\)|" /etc/mkinitcpio.conf
	sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=${CRYPTUUID}:cryptroot root=/dev/mapper/cryptroot\"|" /etc/default/grub
fi

# Generate boot disk
mkinitcpio -p $KERNEL

# Setup admin user and root
useradd -m --uid $USERID $USERNAME
usermod -aG wheel,audio,video,optical,storage $USERNAME
echo "Enter the password for user ${USERNAME}"
passwd $USERNAME
echo 'Enter the password for root'
passwd root

# Ensure that pacman is subscribed to the proper package repo
# according to the chosen init system.
if [[ $INIT_SYSTEM == 'systemd' ]]; then
	# SystemD: Unsubscribe from nonsystemd repo
	sed -i "s|^\[nonsystemd\]|#\[nonsystemd\]|" /etc/pacman.conf
	sed -i "/\[nonsystemd\]/{n;s|^Include.*|#&|}" /etc/pacman.conf
else
	# OpenRC: Subscribe to nonsystemd repo
	sed -i "s|^#\[nonsystemd\]|\[nonsystemd\]|" /etc/pacman.conf
	sed -i "/\[nonsystemd\]/{n;s|^#||}" /etc/pacman.conf
fi

# Install additional packages
pacman -S $EXTRA_PACKAGES

# Install grub bootloader 
if [[ ! -d /boot/efi ]]; then
  mkdir -p /boot/efi
fi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=parabola --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Allow wheel group to execute sudo commands
sed -i "s|^# %wheel ALL=(ALL) ALL|%wheel ALL=(ALL) ALL|" /etc/sudoers

# Enable Network Manager if it was installed.
if pacman -Qi networkmanager 1>/dev/null 2>&1; then
	[[ $INIT_SYSTEM == 'systemd' ]] && systemctl enable NetworkManager || rc-update add NetworkManager default
fi
