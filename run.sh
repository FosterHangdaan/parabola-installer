#!/usr/bin/env bash

# Sanity Checks
# --------------------------------------------------------------
# Check if root
if [[ $UID -ne 0 ]]; then
	echo "ERROR: This script requires root privileges. Exiting..."
	exit 1
fi

# Check if init system is SystemD
if [[ $(ps --no-headers -o comm 1) != "systemd" ]]; then
	echo "ERROR: Init system is not SystemD. Exiting..."
	exit 1
fi

# Check UEFI support.
if [[ ! -d /sys/firmware/efi/efivars ]]; then
	echo "ERROR: UEFI is not enabled in this system. Exiting..."
	exit 1
fi

# Main
# --------------------------------------------------------------
WORKDIR=$(dirname $0)
cd $WORKDIR
source settings.cfg

# Sync System Clock
timedatectl set-ntp true
timedatectl set-timezone "$TZ"

# Verify Package signatures
yes | pacman -Sy archlinux-keyring archlinuxarm-keyring parabola-keyring
yes | pacman -U https://www.parabola.nu/packages/core/i686/archlinux32-keyring-transition/download/

# Add our mirror to the top of the pacman's mirrorlist
echo "$(awk -v "var=$MIRROR" '/^Server \= *./ && !x {print var; x=1} 1' /etc/pacman.d/mirrorlist)" > /etc/pacman.d/mirrorlist

# Install base packages and kernel
pacstrap $CHROOTDIR $BASE_PACKAGES $KERNEL

# Create the proper automount configuration
genfstab -Up $CHROOTDIR >> ${CHROOTDIR}/etc/fstab

# Make this package accessible in chroot by copying it
cp -r $WORKDIR ${CHROOTDIR}/parabola-installer

# Chroot and execute the script
arch-chroot $CHROOTDIR /parabola-installer/chroot.sh

# Cleanup
rm -rf ${CHROOTDIR}/parabola-installer

echo ''
echo 'INSTALLATION COMPLETE'
echo '---------------------'
echo 'Final steps:'
echo "1: Configure pacman in ${CHROOTDIR}/etc/pacman.conf and enable the repositories you need."
echo "2: Unmount the installation disk 'umount -R ${CHROOTDIR}'"
echo "3: If you created an encrypted root partition, then close the mapping using 'cryptsetup close cryptroot'"
echo "4: Reboot the system."
