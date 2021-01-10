# Step 1: Prepare the installation disk
Partition, format and mount the installation disk. You may choose to partition your installation disk with either an encrypted or unencrypted system partition. Although other schemes may also work, only the two schemes shown below have been tested.

**Note:** Replace `/dev/sda` with the appropriate block device.

## Scheme 1: Unencrypted root partition scheme
This scheme uses a simple layout commonly used in Windows systems.

```
GPT Partition Type
+-----------------------+------------------------+-----------------------+
| EFI partition         | System partition       | Optional free space   |
|                       |                        | for additional        |
|                       |                        | partitions to be set  |
| /boot/efi             | /                      | up later              |
|                       |                        |                       |
|                       |                        |                       |
|                       |                        |                       |
| /dev/sda1             | /dev/sda2              |                       |
+-----------------------+------------------------+-----------------------+
```

1. Refer to the scheme above to partition the disk using a partitioning utility such as `fdisk` or `parted`. An example output of `fdisk -l /dev/sda` is shown below:

```
Disk /dev/sda: 931.5 GiB, 1000204886016 bytes, 1953525168 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 636896C6-8CBE-A044-A4A1-0D5000DE55CB

Device       Start        End    Sectors   Size Type
/dev/sda1     2048    1050623    1048576   512M EFI System
/dev/sda2  1050624 1953523711 1952473088 931.0G Linux filesystem
```

2. Prepare the partitions

```
# mkfs.vfat /dev/sda1
# mkfs.ext4 /dev/sda2
# mount /dev/sda2 /mnt
# mkdir -p /mnt/boot/efi
# mount /dev/sda1 /mnt/boot/efi
```

## Scheme 2: Encrypted root partition scheme (LUKS on a partition)
This scheme uses a full system encryption with dm-crypt + LUKS. Refer [here](https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_Entire_System#LUKS_on_a_partition) for a detailed guide.

```
GPT Partition Type
+-----------------------+-----------------------+------------------------+-----------------------+
| EFI partition         | Boot partition        | LUKS2 encrypted system | Optional free space   |
|                       |                       | partition              | for additional        |
|                       |                       |                        | partitions to be set  |
| /boot/efi             | /boot                 | /                      | up later              |
|                       |                       |                        |                       |
|                       |                       | /dev/mapper/cryptroot  |                       |
|                       |                       |------------------------|                       |
| /dev/sda1             | /dev/sda2             | /dev/sda3              |                       |
+-----------------------+-----------------------+------------------------+-----------------------+
```

1. Refer to the scheme above to partition the disk using a partitioning utility such as `fdisk` or `parted`. An example output of `fdisk -l /dev/sda` is shown below:

```
Disk /dev/sda: 20 GiB, 21474836480 bytes, 41943040 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 636896C6-8CBE-A044-A4A1-0D5000DE55CB

Device       Start        End    Sectors   Size Type
/dev/sda1     2048    1050623    1048576   512M EFI System
/dev/sda2  1050624    2549759    1499136   732M Linux filesystem
/dev/sda3  2549760   41943006   39393247  18.8G Linux filesystem
```

2. Prepare the non-boot partition `/dev/sda3`.

```
# cryptsetup -y -v luksFormat --type luks1 /dev/sda3
# cryptsetup open /dev/sda3 cryptroot
# mkfs.ext4 /dev/mapper/cryptroot
# mount /dev/mapper/cryptroot /mnt
```

3. Prepare boot partition `/dev/sda2`.

```
# mkfs.ext4 /dev/sda2
# mkdir /mnt/boot
# mount /dev/sda2 /mnt/boot
```

4. Prepare EFI partition `/dev/sda1`.

```
# mkfs.vfat /dev/sda1
# mkdir /mnt/boot/efi
# mount /dev/sda1 /mnt/boot/efi
```

# Step 2: Establish internet connection
The DHCP service is enabled in the Parabola Live Environment by default and should have acquired the appropriate network settings automatically.

**IMPORTANT:** Ensure that a nameserver has been set in `/etc/resolv.conf`. This is vital to the `chroot.sh` script since the contents of resolv.conf is passed to the chroot environment. You can add a nameserver by executing the command below. Substitute the IP address with your preferred DNS server.
```
# echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
```

Now test the connection by pinging a public server: `ping -c 4 gnu.org`. A successful `ping` will have an output like the one below.
```
PING gnu.org (209.51.188.148) 56(84) bytes of data.
64 bytes from wildebeest.gnu.org (209.51.188.148): icmp_seq=1 ttl=53 time=36.8 ms
64 bytes from wildebeest.gnu.org (209.51.188.148): icmp_seq=2 ttl=53 time=35.6 ms
64 bytes from wildebeest.gnu.org (209.51.188.148): icmp_seq=3 ttl=53 time=37.5 ms
64 bytes from wildebeest.gnu.org (209.51.188.148): icmp_seq=4 ttl=53 time=38.5 ms

--- gnu.org ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 35.666/37.178/38.591/1.071 ms
```

# Step 3: Run the script
Before running the script, change the variables in `settings.cfg` to your preference.

If you copied this repository on the system or a USB, then navigate to its folder and run the script.
```
# cd /path/to/parabola-installer
# ./run.sh
```

Otherwise you will have to clone the repository.
```
# git clone https://gitlab.com/FosterHangdaan/parabola-installer.git
# cd parabola-installer
# ./run.sh
```
**Note:** If git is not installed, then install it with `pacstrap -Sy git`.

# Step 4: Last Steps
Perform the steps below after the script finishes. By default, the installation disk is mounted on `/mnt` and the name of the crypt device is `cryptroot`.

1. Configure pacman in /mnt/etc/pacman.conf and enable the repositories you need.
2. Unmount the installation disk `umount -R /mnt`
3. If you created an encrypted root partition, then close the mapping using `cryptsetup close cryptroot`
4. Reboot the system.
