#!/bin/sh
# EZInstall - Script to install Lirix
# Licensed under the BSD 3-Clause License; for more information, see LICENSE.

echo "Installer for the Lirix distribution of XFree86/Linux"
ezbt=`cat /etc/lirix-release`

mkdir -p /var/log/ezinstall
exec 1> >(tee "/var/log/ezinstall/stdout.log")
exec 2> >(tee "/var/log/ezinstall/stderr.log")

TEXTDOMAINDIR=/usr/local/share/locale
TEXTDOMAIN=ezinstall

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
	csr=`gettext -s "Will create subvolumes: \${btsubvols}"`
	ezmessage "$csr"
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
	csr=`gettext -s "Created BTRFS filesystem on \$1"`
	ezmessage "$csr"
}

ezfilesystem() {
	csr=`gettext -s "Select filesystem to use for Lirix"`
	csra=`gettext -s "Stable filesystem that uses B-Trees. Very good."`
	csrb=`gettext -s "Default filesystem for SGI's IRIX. Journaling cannot be disabled."`
	csrc=`gettext -s "Default filesystem for many Linux distributions. Use if uncomfortable with other options."`
	csrd=`gettext -s "Manually format partition using a shell."`
	ezfs=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 "BTRFS" "$csra" "XFS" "$csrb" "EXT4" "$csrc" "Shell" "$csrd")
	case $ezfs in
		"BTRFS")
			ezbtrfs $1
			;;
		
		"XFS")
			mkfs.xfs -f -m bigtime=1 "$1"
			csr=`gettext -s "Created XFS filesystem on \$1"`
			ezmessage "$csr"
			mount -v "$1" /mnt/lirix
			;;
		
		"EXT4")
			mkfs.ext4 "$1"
			csr=`gettext -s "Created EXT4 filesystem on \$1"`
			ezmessage "$csr"
			mount -v "$1" /mnt/lirix
			;;
		
		"Shell")
			echo `gettext -s ">> Entering interactive Bourne Again Shell."`
			echo `gettext -s ">> Format partition \$1 in whichever way you desire."`
			echo `gettext -s ">> The mountpoint for your Lirix installation is /mnt/lirix"`
			echo `gettext -s ">> Mount \$1 to there when you have completed your manual formatting."`
			echo `gettext -s ">> To return to EZInstall, type exit."`
			/usr/bin/env PS1="\d \t [EZInstall] (\w) > " /bin/bash --norc -i
			;;

		*)
			exit 2;
			;;
	esac
}

ezautopart() {
	csr=`gettext -s "EZAutopartitioning selected.\nWill partition device \$1"`
	ezmessage "$csr"
	if [ -d "/sys/firmware/efi/efivars" ]; then
		csr=`gettext -s "UEFI detected. Will use GPT for partitioning."`
		ezmessage "$csr"
		csr=`gettext -s "Specify swap size in MiB?"`
		if ezconfirmno "$csr"; then
			recswapsize="N/A"
			while ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; do
				csr=`gettext -s "Enter swap size"`
				recswapsize=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "1024");
				if ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; then
					csr=`gettext -s "Swap size must be an integer!"`
					ezmessage "$csr"
				fi
			done
		else
			recswapsize=$(free --mebi | awk '/Mem:/ {print $2}')
		fi
		csr=`gettext -s "Selecting yes now WILL cause data loss.\nContinue?"`
		if ezconfirm "$csr"; then
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

			csr=`gettext -s "EZAutopartitioning complete."`
			ezmessage "$csr"
			swapon "${swappartition}"
			mkdir -pv /mnt/lirix
			ezfilesystem "${lirixpartition}"
			mkdir -pv /mnt/lirix/boot
			mount -v "${bootpartition}" /mnt/lirix/boot
		else
			exit 1;
		fi
	else
		csr=`gettext -s "LegacyBIOS detected. Will use MBR for partitioning."`
		ezmessage "$csr"
		csr=`gettext -s "Specify swap size in MiB?"`
		if ezconfirmno "$csr"; then
			recswapsize="N/A"
			while ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; do
				csr=`gettext -s "Enter swap size"`
				recswapsize=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "1024");
				if ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; then
					csr=`gettext -s "Swap size must be an integer!"`
					ezmessage "$csr"
				fi
			done
		else
			recswapsize=$(free --mebi | awk '/Mem:/ {print $2}')
		fi
		csr=`gettext -s "Selecting yes now WILL cause data loss.\nContinue?"`
		if ezconfirm "$csr"; then
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

			csr=`gettext -s "EZAutopartitioning complete."`
			ezmessage "$csr"
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
		csr=`gettext -s "Enter username for new user"`
		newlirixuser=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0);
		if ! [[ "$newlirixuser" =~ ^[a-z-]+$ ]]; then
			csr=`gettext -s "Username must only contain lowercase letters or the dash (-) symbol and must not be empty."`
			ezmessage "$csr"
		fi
	done


	newlirixpasswd="apa"
	newlirixpasswdconf="aaa"

	while ! [[ "$newlirixpasswd" == "$newlirixpasswdconf" ]]; do
		csr=`gettext -s "Enter password for user \${newlirixuser}\n(default is apioforms)"`
		newlirixpasswd=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "$csr" 0 0)
		if [[ "$newlirixpasswd" == "" ]]; then
			newlirixpasswd="apioforms"
			newlirixpasswdconf="apioforms"
			break;
		fi
		csr=`gettext -s "Me password again."`
		newlirixpasswdconf=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "$csr" 0 0)
		if ! [[ "$newlirixpasswd" == "$newlirixpasswdconf" ]]; then
			csr=`gettext -s "Passwords do NOT match!!"`
			ezmessage "$csr"
		fi
	done

	csr=`gettext -s "Enter description/full name for user \${newlirixuser}"`
	ezuserdescription=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "${newlirixuser}")

	ezgroups="uucp,video,audio,storage,games,input"
	csr=`gettext -s "Do you wish to enable administrative (sudo) privileges for this user?"`
	if ezconfirm "$csr"; then
		ezgroups="wheel,${ezgroups}"
	fi

	csr=`gettext -s "Enter home directory for user \${newlirixuser}"`
	ezhomedir=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "/usr/people/${newlirixuser}")

	csr=`gettext -s "Do you want this user to be able to login?"`
	if ezconfirm "$csr"; then
		arch-chroot /mnt/lirix useradd -d "$ezhomedir" -mU -G "$ezgroups" -k /etc/skel -c "$ezuserdescription" "$newlirixuser"
	else
		arch-chroot /mnt/lirix useradd -d "$ezhomedir" -mU -G "$ezgroups" -k /etc/skel -c "$ezuserdescription" -s /usr/bin/nologin "$newlirixuser"
	fi

	echo "$newlirixuser:$newlirixpasswd" | chpasswd --root /mnt/lirix
}

ezselectlanguage() {
	languagelist=$(cat /etc/locale.gen | grep -Ev '^# |^#$' | sed 's/  //' | grep 'UTF-8 UTF-8' | sed 's/.UTF-8 UTF-8//' | sed 's@#@@g' | awk '1; {printf "-\n"}')
	language=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "josar." 0 0 0 ${languagelist})
	sed -i 's/#${language}.UTF-8 UTF-8/${language}.UTF-8 UTF-8/' /etc/locale.gen
	locale-gen
	LC_ALL="${language}.UTF-8"
}

ezselectlanguage
csr=`gettext -s "Welcome to EZInstall, the installer for Lirix!"`
ezmessage "$csr"
csr=`gettext -s "Would you like to install Lirix at this moment?"`;
if ! ezconfirm "$csr"; then
	exit 0;
fi

keymaplist=$(localectl list-keymaps | awk '1; {printf "-\n"}')
keymap=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu `gettext -s "Select your keymap"` 0 0 0 ${keymaplist})
localectl set-keymap "${keymap}"

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop|sr" | tac)
csr=
if ! device=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --menu `gettext -s "Select installation disk"` 0 0 0 ${devicelist}); then
	exit 1;
else
	csr=`gettext -s "Do you wish to partition \$device?"`
	if ezconfirm "$csr"; then
		csr=`gettext -s "Do you wish to autopartition \$device?"`
		if $(ezconfirm "$csr"); then
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
		csr=`gettext -s "Select boot partition"`
		bootpartition=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --no-cancel --menu "$csr" 0 0 0 ${partlist})
	fi
	csr=`gettext -s "Select swap partition"`
	swappartition=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 ${partlist});
	csr=`gettext -s "Select Lirix partition"`
	lirixpartition=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --no-cancel --menu "$csr" 0 0 0 ${partlist});

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
	
	csr=`gettext -s "Would you like to enter an interactive shell to manually configure more advanced options before proceeding?"`
	if ezconfirmno "$csr"; then
		echo `gettext -s ">> Entering interactive Bourne Again Shell."`
		echo `gettext -s ">> The root mountpoint of the Lirix installation is /mnt/lirix"`
		echo `gettext -s ">> Once complete, return to EZInstall by typing exit."`
		/usr/bin/env PS1="\d \t [EZInstall] (\w) > " /bin/bash --norc -i
	fi
fi

csr=`gettext -s "Starting installation of Lirix. Setup will continue shortly hereafter."`
ezmessage "$csr"
unsquashfs -f -d /mnt/lirix /opt/lirix/rootfs.squashfs
csr=`gettext -s "Installation complete. Setup will now continue."`
ezmessage "$csr"
genfstab -U /mnt/lirix >> /mnt/lirix/etc/fstab

cp -pv /etc/X11/xorg.conf.d/00-keyboard.conf /mnt/lirix/etc/X11/xorg.conf.d/00-keyboard.conf
echo "KEYMAP=${keymap}" > /mnt/lirix/etc/vconsole.conf

hostname="3"
while ! [[ "$hostname" =~ ^[a-z-]*$ ]]; do
	csr=`gettext -s "Enter hostname for system\n(default is apioform-hive)"`
	hostname=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0);
	if ! [[ "$hostname" =~ ^[a-z-]*$ ]]; then
		csr=`gettext -s "Hostname must only contain lowercase letters or the dash (-) symbol."`
		ezmessage "$csr"
	fi
done

if [[ "$hostname" == "" ]]; then
	hostname="apioform-hive"
fi

lirixuser="3"
while ! [[ "$lirixuser" =~ ^[a-z-]*$ ]]; do
	csr=`gettext -s "Enter username for main user\n(default is aamoo)"`
	lirixuser=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0);
	if ! [[ "$lirixuser" =~ ^[a-z-]*$ ]]; then
		csr=`gettext -s "Username must only contain lowercase letters or the dash (-) symbol."`
		ezmessage "$csr"
	fi
done

if [[ "$lirixuser" == "" ]]; then
	lirixuser="aamoo"
fi

lirixpasswd="apa"
lirixpasswdconf="aaa"

while ! [[ "$lirixpasswd" == "$lirixpasswdconf" ]]; do
	csr=`gettext -s "Enter password for user \${lirixuser}\n(default is apioforms)"`
	lirixpasswd=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "$csr" 0 0)
	if [[ "$lirixpasswd" == "" ]]; then
		lirixpasswd="apioforms"
		lirixpasswdconf="apioforms"
		break;
	fi
	csr=`gettext -s "Me password again."`
	lirixpasswdconf=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "$csr" 0 0)
	if ! [[ "$lirixpasswd" == "$lirixpasswdconf" ]]; then
		csr=`gettext -s "Passwords do NOT match!!"`
		ezmessage "$csr"
	fi
done

csr=`gettext -s "Enter description/full name for user \${lirixuser}"`
lirixuserdescription=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "${lirixuser}")

echo "${hostname}" >> /mnt/lirix/etc/hostname
echo "127.0.0.1		localhost" >> /mnt/lirix/etc/hosts
echo "::1		localhost" >> /mnt/lirix/etc/hosts
echo "127.0.0.1		${hostname}.localdomain		${hostname}" >> /mnt/lirix/etc/hosts

arch-chroot /mnt/lirix useradd -d /usr/people/"$lirixuser" -mU -G wheel,uucp,video,audio,storage,games,input -k /etc/skel -c "$lirixuserdescription" "$lirixuser"
echo "$lirixuser:$lirixpasswd" | chpasswd --root /mnt/lirix

ezaddmoreusers="yes"
while [[ "$ezaddmoreusers" == "yes" ]]; do
	csr=`gettext -s "Do you wish to add an additional user?"`
	if ezconfirmno "$csr"; then
		ezadduser
	else
		ezaddmoreusers="no"
	fi
done

zonelist=$(find /usr/share/zoneinfo ! -type d | awk '1 ; {printf "-\n"}' | sed 's@/usr/share/zoneinfo/@@g')
csr=`gettext -s "Select timezone"`
timezone=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 ${zonelist});

ln -sfv /mnt/lirix/usr/share/zoneinfo/${timezone} /mnt/lirix/etc/localtime
arch-chroot /mnt/lirix hwclock --systohc

localelist=$(cat /etc/locale.gen | grep -Ev '^# |^#$' | sed 's/  //' | grep 'UTF-8 UTF-8' | sed 's/.UTF-8 UTF-8//' | sed 's@#@@g')
checklistInDialogIsBad=()
while IFS= read -r line; do
	checklistInDialogIsBad+=("$line" "-" "off")
done <<< "$localelist"
IFS=" "
csr=`gettext -s "Select locale. To check a box, press the spacebar key. When you have completed your selection of locales, press the enter key."`
locales=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --checklist "$csr" 0 0 0 "${checklistInDialogIsBad[@]}"})
localenumber=$(echo -e "${locales}" | wc)
if [[ "${localenumber}" == "0" ]]; then
	locales="en_US"
	localenumber="1"
fi

if ! [[ "${localenumber}" == "1"]]; then
	localepreferencelist=$(echo -e "${locales}" | awk -v RS=" " '{print}' | awk '1 ; {printf "-\n"'})
	csr=`gettext -s "Select preferred locale"`
	preferredlocale=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 "${localepreferencelist}")
else
	preferredlocale=locales
fi

for ezlocale in locales; do
	sed -i 's/#${ezlocale}.UTF-8 UTF-8/${ezlocale}.UTF-8 UTF-8/' /mnt/lirix/etc/locale.gen
done

arch-chroot /mnt/lirix locale-gen
touch /mnt/lirix/etc/locale.conf
echo 'LANG=${preferredlocale}.UTF-8' >> /mnt/lirix/etc/locale.conf

if [ -d "/sys/firmware/efi/efivars" ]; then
	arch-chroot /mnt/lirix grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
	arch-chroot /mnt/lirix grub-install --target=i386-pc "$device"
fi
arch-chroot /mnt/lirix grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot /mnt/lirix mkinitcpio -P

csr=`gettext -s "Lirix setup complete. Reboot now?"`
if ezconfirm "$csr"; then
	reboot
fi