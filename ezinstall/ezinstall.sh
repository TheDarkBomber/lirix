#!/bin/sh
# EZInstall - Script to install Lirix
# Licensed under the BSD 3-Clause License; for more information, see LICENSE.

echo "Installer for the Lirix distribution of XFree86/Linux"

ezmessage() {
	dialog --stdout --aspect 120 --msgbox "$@" 0 0
}

ezconfirm() {
	dialog --stdout --aspect 120 --yesno "$@" 0 0
}

ezbtrfs() {
	btsubvols="\n/\n/usr/people\n/var/log"
	ezmessage "Customising BTRFS subvolumes not yet implemented, will create subvolumes: ${btsubvols}"
	mkfs.btrfs -f "$1"
	mount -v "$1" /mnt/lirix
	btrfs su cr /mnt/lirix/@
	btrfs su cr /mnt/lirix/@usrpeople
	btrfs su cr /mnt/lirix/@varlog
	umount /mnt/lirix
	mount -v -o noatime,compress=lzo,space_cache=v2,subvol=@ "$1" /mnt/lirix
	mkdir -pv /mnt/lirix/{usr/people,var/log}
	mount -v -o noatime,compress=lzo,space_cache=v2,subvol=@usrpeople "$1" /mnt/lirix/usr/people
	mount -v -o noatime,compress=lzo,space_cache=v2,subvol=@varlog "$1" /mnt/lirix/var/log
	ezmessage "Created BTRFS filesystem on $1"
}

ezfilesystem() {
	ezfs=$(dialog --stdout --aspect 120 --no-cancel --menu "Select filesystem to use for Lirix" 0 0 0 "BTRFS" "Stable filesystem that uses B-Trees. Very good." "XFS" "Default filesystem for SGI's IRIX. Journaling cannot be disabled." "EXT4" "Default filesystem for many Linux distributions. Use if uncomfortable with other options.")
	case $ezfs in
		"BTRFS")
			ezbtrfs $1
			;;
		
		"XFS")
			mkfs.xfs -f -m bigtime=1 "$1"
			ezmessage "Created XFS filesystem on $1"
			mount -v "$1" /mnt/lirix
			;;
		
		"EXT4")
			mkfs.ext4 "$1"
			ezmessage "Created EXT4 filesystem on $1"
			mount -v "$1" /mnt/lirix
			;;

		*)
			exit 2;
			;;
	esac
}

ezautopart() {
	ezmessage "EZAutopartitioning selected.\nWill partition device $1"
	if [ -d "/sys/firmware/efi/efivars" ]; then
		ezmessage "UEFI detected. Will use GPT for partitioning."
		if ezconfirm "Use fixed swap size 1024MiB?"; then
			recswapsize=1024
		else
			recswapsize=$(free --mebi | awk '/Mem:/ {print $2}')
		fi
		if ezconfirm "Selecting yes now WILL cause data loss.\nContinue?"; then
			recswapend=$(( $recswapsize + 130))MiB

			parted --script "${1}" -a optimal -- mklabel gpt \
			mkpart ESP fat32 1MiB 512MiB \
			set 1 boot on \
			mkpart Swap linux-swap 512MiB ${recswapend} \
			set 2 swap on \
			mkpart Lirix ext4 ${recswapend} 100%

			sgdisk -t 1:ef00 ${1}
			sgdisk -t 3:8304 ${1}

			partlist=$(lsblk -plnx name $device -o name,size | grep -Ev "boot|rpmb|loop" | tail -n +2)
			bootpartition=$(echo $partlist | cut -d ' ' -f 1)
			swappartition=$(echo $partlist | cut -d ' ' -f 3)
			lirixpartition=$(echo $partlist | cut -d ' ' -f 5)

			mkfs.vfat -F32 "${bootpartition}"
			mkswap "${swappartition}"

			ezmessage "EZAutopartitioning complete."
			swapon "${swappartition}"
			mkdir -pv /mnt/lirix
			ezfilesystem "${lirixpartition}"
			mkdir -pv /mnt/lirix/boot
			mount -v "${bootpartition}" /mnt/lirix/boot
		else
			exit 1;
		fi
	else
		ezmessage "LegacyBIOS detected. Will use MBR for partitioning."
		if ezconfirm "Use fixed swap size 1024MiB?"; then
			recswapsize=1024
		else
			recswapsize=$(free --mebi | awk '/Mem:/ {print $2}')
		fi
		if ezconfirm "Selecting yes now WILL cause data loss.\nContinue?"; then
			recswapend=$(( $recswapsize + 130))MiB

			parted --script "${1}" -a optimal -- mklabel msdos \
			mkpart primary linux-swap 1MiB ${recswapend} \
			mkpart primary ext4 ${recswapend} 100%

			sfdisk --part-type ${1} 2 83
			sfdisk --part-type ${1} 1 82

			partlist=$(lsblk -plnx name $device -o name,size | grep -Ev "boot|rpmb|loop" | tail -n +2)
			swappartition=$(echo $partlist | cut -d ' ' -f 1)
			lirixpartition=$(echo $partlist | cut -d ' ' -f 3)

			mkswap "${swappartition}"

			ezmessage "EZAutopartitioning complete."
			swapon "${swappartition}"
			mkdir -pv /mnt/lirix/
			ezfilesystem "${lirixpartition}"
			mkdir -pv /mnt/lirix/boot
		else
			exit 1;
		fi
	fi	
}

ezmessage "Welcome to EZInstall, the installer for Lirix!"
if ! ezconfirm "Would you like to install Lirix at this moment?"; then
	exit 0;
fi

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop|sr" | tac)
if ! device=$(dialog --stdout --aspect 120 --menu "Select installation disk" 0 0 0 ${devicelist}); then
	exit 1;
else
	if ezconfirm "Do you wish to partition $device?"; then
		if $(ezconfirm "Do you wish to autopartition $device?"); then
			autopart="value"
			ezautopart $device
		else
			cfdisk -L $device
		fi
	fi
fi

if [[ "$autopart" != "value" ]]; then
	partlist=$(lsblk -plnx name $device -o name,size | grep -Ev "boot|rpmb|loop" | tail -n +2)
	if [ -d "/sys/firmware/efi/efivars" ]; then
		bootpartition=$(dialog --stdout --aspect 120 --no-cancel --menu "Select boot partition" 0 0 0 ${partlist})
	fi
	swappartition=$(dialog --stdout --aspect 120 --menu "Select swap partition" 0 0 0 ${partlist});
	lirixpartition=$(dialog --stdout --aspect 120 --no-cancel --menu "Select Lirix partition" 0 0 0 ${partlist});

	mkdir -pv /mnt/lirix
	ezfilesystem "${lirixpartition}"
	mkdir -pv /mnt/lirix/boot

	if [[ "$bootpartition" != "" ]]; then
		mkfs.vfat -F32 $bootpartition
		mount -v $bootpartition /mnt/lirix/boot
	fi

	if [[ "$swappartition" != "" ]]; then
		mkswap $swappartition
		swapon $swappartition
	fi
fi

ezmessage "Starting installation of Lirix. Setup will continue shortly hereafter."
unsquashfs -f -d /mnt/lirix /opt/lirix/rootfs.squashfs
ezmessage "Installation complete. Setup will now continue."
genfstab -U /mnt/lirix >> /mnt/lirix/etc/fstab

hostname="3"
while ! [[ "$hostname" =~ ^[a-z-]*$ ]]; do
	hostname=$(dialog --stdout --inputbox "Enter hostname for system\n(default is apioform-hive)" 0 0);
	if ! [[ "$hostname" =~ ^[a-z-]*$ ]]; then
		ezmessage "Hostname must only contain lowercase letters or the dash (-) symbol."
	fi
done

if [[ "$hostname" == "" ]]; then
	hostname="apioform-hive"
fi

lirixuser="3"
while ! [[ "$lirixuser" =~ ^[a-z-]*$ ]]; do
	lirixuser=$(dialog --stdout --inputbox "Enter username for main user\n(default is aamoo)" 0 0);
	if ! [[ "$lirixuser" =~ ^[a-z-]*$ ]]; then
		ezmessage "Username must only contain lowercase letters or the dash (-) symbol."
	fi
done

if [[ "$lirixuser" == "" ]]; then
	lirixuser="aamoo"
fi

lirixpasswd="apa"
lirixpasswdconf="aaa"

while ! [[ "$lirixpasswd" == "$lirixpasswdconf" ]]; do
	lirixpasswd=$(dialog --stdout --passwordbox "Enter password for user ${lirixuser}\n(default is apioforms)" 0 0)
	if [[ "$lirixpasswd" == "" ]]; then
		lirixpasswd="apioforms"
		lirixpasswdconf="apioforms"
		break;
	fi
	lirixpasswdconf=$(dialog --stdout --passwordbox "Me password again." 0 0)
	if ! [[ "$lirixpasswd" == "$lirixpasswdconf" ]]; then
		ezmessage "Passwords do NOT match!!"
	fi
done

echo "${hostname}" >> /mnt/lirix/etc/hostname
echo "127.0.0.1		localhost" >> /mnt/lirix/etc/hosts
echo "::1		localhost" >> /mnt/lirix/etc/hosts
echo "127.0.0.1		${hostname}.localdomain		${hostname}" >> /mnt/lirix/etc/hosts

#regionlist=$(ls -1 /mnt/lirix/usr/share/zoneinfo)
#timeregion=$(dialog --stdout --aspect 120 --no-cancel --menu "Select time region" 0 0 0 ${regionlist});

#citylist=$(ls -1 /mnt/lirix/usr/share/zoneinfo/${timeregion})
#timecity=$(dialog --stdout --aspect 120 --no-cancel --menu "Select time city" 0 0 0 ${citylist});

#ln -sfv /mnt/lirix/usr/share/zoneinfo/${timeregion}/${timecity} /mnt/lirix/etc/localtime
#arch-chroot /mnt/lirix hwclock --systohc

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/lirix/etc/locale.gen
arch-chroot /mnt/lirix locale-gen
touch /mnt/lirix/etc/locale.conf
echo 'LANG=en_US.UTF-8' >> /mnt/lirix/etc/locale.conf

arch-chroot /mnt/lirix useradd -d /usr/people/"$lirixuser" -mU -G wheel,uucp,video,audio,storage,games,input -k /etc/skel "$lirixuser"
echo "$lirixuser:$lirixpasswd" | chpasswd --root /mnt/lirix

if [ -d "/sys/firmware/efi/efivars" ]; then
	arch-chroot /mnt/lirix grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
	arch-chroot /mnt/lirix grub-install --target=i386-pc "$device"
fi
arch-chroot /mnt/lirix grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot /mnt/lirix mkinitcpio -P


if ezconfirm "Lirix setup complete. Reboot now?"; then
	reboot
fi