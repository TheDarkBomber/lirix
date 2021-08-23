#!/bin/sh
# EZInstall - Script to install Lirix
# Licensed under the BSD 3-Clause License; for more information, see LICENSE.

echo "Installer for the Lirix distribution of XFree86/Linux"
ezbt=`cat /etc/lirix-release`

mkdir -p /var/log/ezinstall
exec 1> >(tee "/var/log/ezinstall/stdout.log")
exec 2> >(tee "/var/log/ezinstall/stderr.log")

ezmessage() {
	dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --msgbox "$@" 0 0
}

ezconfirm() {
	dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --yesno "$@" 0 0
}

ezconfirmno() {
	dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --defaultno --yesno "$@" 0 0
}

ezbtrfs() {
	btsubvols="\n/\n/usr/people\n/var/log"
	ezmessage "Will create subvolumes: ${btsubvols}"
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
	ezfs=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "Select filesystem to use for Lirix" 0 0 0 "BTRFS" "Stable filesystem that uses B-Trees. Very good." "XFS" "Default filesystem for SGI's IRIX. Journaling cannot be disabled." "EXT4" "Default filesystem for many Linux distributions. Use if uncomfortable with other options." "Shell" "Manually format partition using a shell.")
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
		
		"Shell")
			echo ">> Entering interactive Bourne Again Shell."
			echo ">> Format partition $1 in whichever way you desire."
			echo ">> The mountpoint for your Lirix installation is /mnt/lirix"
			echo ">> Mount $1 to there when you have completed your manual formatting."
			echo ">> To return to EZInstall, type exit."
			/usr/bin/env PS1="\d \t [EZInstall] (\w) > " /bin/bash --norc -i
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
		if ezconfirmno "Specify swap size in MiB?"; then
			recswapsize="N/A"
			while ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; do
				recswapsize=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "Enter swap size" 0 0 "1024");
				if ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; then
					ezmessage "Swap size must be an integer!"
				fi
			done
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

ezadduser() {
	newlirixuser="3"
	while ! [[ "$newlirixuser" =~ ^[a-z-]+$ ]]; do
		newlirixuser=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "Enter username for new user" 0 0);
		if ! [[ "$newlirixuser" =~ ^[a-z-]+$ ]]; then
			ezmessage "Username must only contain lowercase letters or the dash (-) symbol and must not be empty."
		fi
	done


	newlirixpasswd="apa"
	newlirixpasswdconf="aaa"

	while ! [[ "$newlirixpasswd" == "$newlirixpasswdconf" ]]; do
		newlirixpasswd=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "Enter password for user ${newlirixuser}\n(default is apioforms)" 0 0)
		if [[ "$newlirixpasswd" == "" ]]; then
			newlirixpasswd="apioforms"
			newlirixpasswdconf="apioforms"
			break;
		fi
		newlirixpasswdconf=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "Me password again." 0 0)
		if ! [[ "$newlirixpasswd" == "$newlirixpasswdconf" ]]; then
			ezmessage "Passwords do NOT match!!"
		fi
	done

	ezuserdescription=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "Enter description/full name for user ${newlirixuser}" 0 0 "${newlirixuser}")

	ezgroups="uucp,video,audio,storage,games,input"
	if ezconfirm "Do you wish to enable administrative (sudo) privileges for this user?"; then
		ezgroups="wheel,${ezgroups}"
	fi

	ezhomedir=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "Enter home directory for user ${newlirixuser}" 0 0 "/usr/people/${newlirixuser}")

	if ezconfirm "Do you want this user to be able to login?"; then
		arch-chroot /mnt/lirix useradd -d "$ezhomedir" -mU -G "$ezgroups" -k /etc/skel -c "$ezuserdescription" "$newlirixuser"
	else
		arch-chroot /mnt/lirix useradd -d "$ezhomedir" -mU -G "$ezgroups" -k /etc/skel -c "$ezuserdescription" -s /usr/bin/nologin "$newlirixuser"
	fi

	echo "$newlirixuser:$newlirixpasswd" | chpasswd --root /mnt/lirix
}

ezmessage "Welcome to EZInstall, the installer for Lirix!"
if ! ezconfirm "Would you like to install Lirix at this moment?"; then
	exit 0;
fi

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop|sr" | tac)
if ! device=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --menu "Select installation disk" 0 0 0 ${devicelist}); then
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
		bootpartition=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --no-cancel --menu "Select boot partition" 0 0 0 ${partlist})
	fi
	swappartition=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --menu "Select swap partition" 0 0 0 ${partlist});
	lirixpartition=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --no-cancel --menu "Select Lirix partition" 0 0 0 ${partlist});

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

	if ezconfirmno "Would you like to enter an interactive shell to manually configure more advanced options before proceeding?"; then
		echo ">> Entering interactive Bourne Again Shell."
		echo ">> The root mountpoint of the Lirix installation is /mnt/lirix"
		echo ">> Once complete, return to EZInstall by typing exit."
		/usr/bin/env PS1="\d \t [EZInstall] (\w) > " /bin/bash --norc -i
	fi
fi

ezmessage "Starting installation of Lirix. Setup will continue shortly hereafter."
unsquashfs -f -d /mnt/lirix /opt/lirix/rootfs.squashfs
ezmessage "Installation complete. Setup will now continue."
genfstab -U /mnt/lirix >> /mnt/lirix/etc/fstab

hostname="3"
while ! [[ "$hostname" =~ ^[a-z-]*$ ]]; do
	hostname=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "Enter hostname for system\n(default is apioform-hive)" 0 0);
	if ! [[ "$hostname" =~ ^[a-z-]*$ ]]; then
		ezmessage "Hostname must only contain lowercase letters or the dash (-) symbol."
	fi
done

if [[ "$hostname" == "" ]]; then
	hostname="apioform-hive"
fi

lirixuser="3"
while ! [[ "$lirixuser" =~ ^[a-z-]*$ ]]; do
	lirixuser=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "Enter username for main user\n(default is aamoo)" 0 0);
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
	lirixpasswd=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "Enter password for user ${lirixuser}\n(default is apioforms)" 0 0)
	if [[ "$lirixpasswd" == "" ]]; then
		lirixpasswd="apioforms"
		lirixpasswdconf="apioforms"
		break;
	fi
	lirixpasswdconf=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "Me password again." 0 0)
	if ! [[ "$lirixpasswd" == "$lirixpasswdconf" ]]; then
		ezmessage "Passwords do NOT match!!"
	fi
done

lirixuserdescription=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "Enter description/full name for user ${lirixuser}" 0 0 "${lirixuser}")

echo "${hostname}" >> /mnt/lirix/etc/hostname
echo "127.0.0.1		localhost" >> /mnt/lirix/etc/hosts
echo "::1		localhost" >> /mnt/lirix/etc/hosts
echo "127.0.0.1		${hostname}.localdomain		${hostname}" >> /mnt/lirix/etc/hosts

arch-chroot /mnt/lirix useradd -d /usr/people/"$lirixuser" -mU -G wheel,uucp,video,audio,storage,games,input -k /etc/skel -c "$lirixuserdescription" "$lirixuser"
echo "$lirixuser:$lirixpasswd" | chpasswd --root /mnt/lirix

ezaddmoreusers="yes"
while [[ "$ezaddmoreusers" == "yes" ]]; do
	if ezconfirmno "Do you wish to add an additional user?"; then
		ezadduser
	else
		ezaddmoreusers="no"
	fi
done

zonelist=$(find /usr/share/zoneinfo ! -type d | awk '1 ; {printf "-\n"}' | sed 's@/usr/share/zoneinfo/@@g')
timeregion=$(dialog --stdout --aspect 120 --no-cancel --menu "Select timezone" 0 0 0 ${zonelist});

ln -sfv /mnt/lirix/usr/share/zoneinfo/${timezone} /mnt/lirix/etc/localtime
arch-chroot /mnt/lirix hwclock --systohc

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/lirix/etc/locale.gen
arch-chroot /mnt/lirix locale-gen
touch /mnt/lirix/etc/locale.conf
echo 'LANG=en_US.UTF-8' >> /mnt/lirix/etc/locale.conf

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