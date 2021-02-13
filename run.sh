#!/usr/bin/env bash

WORKDIR=$(dirname $0)
cd $WORKDIR
source settings.cfg
source color-echo.sh

# Initial Sanity Checks
# --------------------------------------------------------------
# Check if root.
if [[ $UID -ne 0 ]]; then
	colorEcho 'red' "ERROR: This script requires root privileges. Exiting..."
	exit 1
fi

# Check UEFI support.
if [[ ! -d /sys/firmware/efi/efivars ]]; then
	colorEcho 'red' "ERROR: UEFI is not enabled in this system. Exiting..."
	exit 1
fi

# Check if the chosen init system is supported.
if ! [[ $INIT_SYSTEM =~ ^(systemd|openrc)$ ]]; then
	colorEcho 'red' "ERROR: $INIT_SYSTEM is not supported. Please choose either openrc or systemd."
	exit 1
fi

# Main
# --------------------------------------------------------------

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

# Ensure system clock is synchronized.
if command -v timedatectl > /dev/null; then
	timedatectl set-timezone "$TZ"
	timedatectl set-ntp true
else
	# Sync time the old-fashioned way and force a refresh.
	ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
	yes | pacman -Sy ntp
	ntpd -qg
fi

# Verify Package signatures
yes | pacman -Sy archlinux-keyring archlinuxarm-keyring parabola-keyring
yes | pacman -U https://www.parabola.nu/packages/core/i686/archlinux32-keyring-transition/download/

# Add our mirror to the top of the pacman's mirrorlist
echo "$(awk -v "var=Server = $MIRROR" '/^Server \= *./ && !x {print var; x=1} 1' /etc/pacman.d/mirrorlist)" > /etc/pacman.d/mirrorlist

# Install base packages and kernel
if [[ $INIT_SYSTEM == 'systemd' ]]; then
	pacstrap $CHROOTDIR $SYSTEMD_BASE_PACKAGES $SCRIPT_PACKAGES $KERNEL $EXTRA_PACKAGES
else
	pacstrap $CHROOTDIR $OPENRC_BASE_PACKAGES $SCRIPT_PACKAGES $KERNEL $EXTRA_PACKAGES
fi

# Create the proper automount configuration
genfstab -Up $CHROOTDIR >> ${CHROOTDIR}/etc/fstab

# Make this package accessible in chroot by copying it
cp -r $WORKDIR ${CHROOTDIR}/parabola-installer

# Chroot and execute the script
arch-chroot $CHROOTDIR /parabola-installer/chroot.sh

# Cleanup
rm -rf ${CHROOTDIR}/parabola-installer

echo ''
colorEcho 'green' 'INSTALLATION COMPLETE'
colorEcho 'green' '---------------------'
colorEcho 'green' 'Final steps:'
colorEcho 'green' "1: Configure pacman in ${CHROOTDIR}/etc/pacman.conf and enable the repositories you need."
colorEcho 'green' "2: Unmount the installation disk 'umount -R ${CHROOTDIR}'"
colorEcho 'green' "3: If you created an encrypted root partition, then close the mapping using 'cryptsetup close cryptroot'"
colorEcho 'green' "4: Reboot the system."
