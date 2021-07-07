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

			partlist=$(lsblk -plnx size $device -o name,size | grep -Ev "boot|rpmb|loop" | sort | tail -n +2)
			bootpartition=$(echo $partlist | cut -d ' ' -f 1)
			swappartition=$(echo $partlist | cut -d ' ' -f 3)
			lirixpartition=$(echo $partlist | cut -d ' ' -f 5)

			mkfs.vfat -F32 "${bootpartition}"
			mkswap "${swappartition}"
			mkfs.ext4 "${lirixpartition}"

			ezmessage "EZAutopartitioning complete."
			swapon "${swappartition}"
			mkdir -pv /mnt/lirix
			mount -v "${lirixpartition}" /mnt/lirix
			mkdir -pv /mnt/lirix/boot
			mount -v "${bootpartition}" /mnt/lirix/boot

			ezmessage $partlist
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

			parted --script "${1}" -a optimal -- mklabel dos \
			mkpart primary linux-swap 512MiB ${recswapend} \
			set 1 swap on \
			mkpart primary ext4 ${recswapend} 100%

			sfdisk --change-id ${1} 2 83

			partlist=$(lsblk -plnx size $device -o name,size | grep -Ev "boot|rpmb|loop" | sort | tail -n +2)
			swappartition=$(echo $partlist | cut -d ' ' -f 1)
			lirixpartition=$(echo $partlist | cut -d ' ' -f 3)

			mkswap "${swappartition}"
			mkfs.ext4 "${lirixpartition}"

			ezmessage "EZAutopartitioning complete."
			swapon "${swappartition}"
			mkdir -pv /mnt/lirix/
			mount -v "${lirixpartition}" /mnt/lirix
			mkdir -pv /mnt/lirix/boot

			ezmessage $partlist
		else
			exit 1;
		fi
	fi	
}

ezmessage "Welcome to EZInstall, the installer for Lirix!"
if ! ezconfirm "Would you like to install Lirix at this moment?"; then
	exit 0;
fi

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
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
	partlist=$(lsblk -plnx size $device -o name,size | grep -Ev "boot|rpmb|loop" | sort | tail -n +2)
	if [ -d "/sys/firmware/efi/efivars" ]; then
		bootpartition=$(dialog --stdout --aspect 120 --no-cancel --menu "Select boot partition" 0 0 0 ${partlist})
	fi
	swappartition=$(dialog --stdout --aspect 120 --menu "Select swap partition" 0 0 0 ${partlist});
	lirixpartition=$(dialog --stdout --aspect 120 --no-cancel --menu "Select Lirix partition" 0 0 0 ${partlist});

	mkdir -pv /mnt/lirix
	mkfs.ext4 $lirixpartition
	mount -v $lirixpartition /mnt/lirix
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

hostname=$(dialog --stdout --inputbox "Enter hostname for system\n(default is apioform-hive)" 0 0); 
if [[ "$hostname" == "" ]]; then
	hostname="apioform-hive"
fi

lirixuser=$(dialog --stdout --inputbox "Enter username for main user\n(default is aamoo)" 0 0);
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


if ezconfirm "Lirix setup complete. Reboot now?"; then
	reboot
fi