#!/bin/sh
# EZInstall - Script to install Lirix
# Licensed under the BSD 3-Clause License; for more information, see LICENSE.

echo "Installer for the Lirix distribution of XFree86/Linux"
ezbt=`cat /etc/lirix-release`

mkdir -p /var/log/ezinstall
exec 1> >(tee "/var/log/ezinstall/stdout.log")
exec 2> >(tee "/var/log/ezinstall/stderr.log")

export TEXTDOMAINDIR=/usr/local/share/locale
export TEXTDOMAIN=ezinstall
. gettext.sh

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
	csr=`eval_gettext "Will create subvolumes: \\\${btsubvols}"`
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
	cfv="$1"
	csr=`eval_gettext "Created BTRFS filesystem on \\\$cfv"`
	ezmessage "$csr"
}

ezfilesystem() {
	csr=`eval_gettext "Select filesystem to use for Lirix"`
	csra=`eval_gettext "Stable filesystem that uses B-Trees. Very good."`
	csrb=`eval_gettext "Default filesystem for SGI's IRIX. Journaling cannot be disabled."`
	csrc=`eval_gettext "Default filesystem for many Linux distributions. Use if uncomfortable with other options."`
	csrd=`eval_gettext "Manually format partition using a shell."`
	ezfs=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 "BTRFS" "$csra" "XFS" "$csrb" "EXT4" "$csrc" "Shell" "$csrd")
	case $ezfs in
		"BTRFS")
			ezbtrfs $1
			;;
		
		"XFS")
			mkfs.xfs -f -m bigtime=1 "$1"
			cfv="$1"
			csr=`eval_gettext "Created XFS filesystem on \\\$cfv"`
			ezmessage "$csr"
			mount -v "$1" /mnt/lirix
			;;
		
		"EXT4")
			mkfs.ext4 "$1"
			cfv="$1"
			csr=`eval_gettext "Created EXT4 filesystem on \\\$cfv"`
			ezmessage "$csr"
			mount -v "$1" /mnt/lirix
			;;
		
		"Shell")
			cfv="$1"
			echo `eval_gettext ">> Entering interactive Bourne Again Shell."`
			echo `eval_gettext ">> Format partition \\\$cfv in whichever way you desire."`
			echo `eval_gettext ">> The mountpoint for your Lirix installation is /mnt/lirix"`
			echo `eval_gettext ">> Mount \\\$cfv to there when you have completed your manual formatting."`
			echo `eval_gettext ">> To return to EZInstall, type exit."`
			/usr/bin/env PS1="\d \t [EZInstall] (\w) > " /bin/bash --norc -i
			;;

		*)
			exit 2;
			;;
	esac
}

ezautopart() {
	cfv="$1"
	csr=`eval_gettext "EZAutopartitioning selected.\nWill partition device \\\$cfv"`
	ezmessage "$csr"
	if [ -d "/sys/firmware/efi/efivars" ]; then
		csr=`eval_gettext "UEFI detected. Will use GPT for partitioning."`
		ezmessage "$csr"
		csr=`eval_gettext "Specify swap size in MiB?"`
		if ezconfirmno "$csr"; then
			recswapsize="N/A"
			while ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; do
				csr=`eval_gettext "Enter swap size"`
				recswapsize=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "1024");
				if ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; then
					csr=`eval_gettext "Swap size must be an integer!"`
					ezmessage "$csr"
				fi
			done
		else
			recswapsize=$(free --mebi | awk '/Mem:/ {print $2}')
		fi
		csr=`eval_gettext "Selecting yes now WILL cause data loss.\nContinue?"`
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

			csr=`eval_gettext "EZAutopartitioning complete."`
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
		csr=`eval_gettext "LegacyBIOS detected. Will use MBR for partitioning."`
		ezmessage "$csr"
		csr=`eval_gettext "Specify swap size in MiB?"`
		if ezconfirmno "$csr"; then
			recswapsize="N/A"
			while ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; do
				csr=`eval_gettext "Enter swap size"`
				recswapsize=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "1024");
				if ! [[ "$recswapsize" =~ ^[0-9]+$ ]]; then
					csr=`eval_gettext "Swap size must be an integer!"`
					ezmessage "$csr"
				fi
			done
		else
			recswapsize=$(free --mebi | awk '/Mem:/ {print $2}')
		fi
		csr=`eval_gettext "Selecting yes now WILL cause data loss.\nContinue?"`
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

			csr=`eval_gettext "EZAutopartitioning complete."`
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
		csr=`eval_gettext "Enter username for new user"`
		newlirixuser=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0);
		if ! [[ "$newlirixuser" =~ ^[a-z-]+$ ]]; then
			csr=`eval_gettext "Username must only contain lowercase letters or the dash (-) symbol and must not be empty."`
			ezmessage "$csr"
		fi
	done


	newlirixpasswd="apa"
	newlirixpasswdconf="aaa"

	while ! [[ "$newlirixpasswd" == "$newlirixpasswdconf" ]]; do
		csr=`eval_gettext "Enter password for user \\\${newlirixuser}\n(default is apioforms)"`
		newlirixpasswd=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "$csr" 0 0)
		if [[ "$newlirixpasswd" == "" ]]; then
			newlirixpasswd="apioforms"
			newlirixpasswdconf="apioforms"
			break;
		fi
		csr=`eval_gettext "Me password again."`
		newlirixpasswdconf=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "$csr" 0 0)
		if ! [[ "$newlirixpasswd" == "$newlirixpasswdconf" ]]; then
			csr=`eval_gettext "Passwords do NOT match!!"`
			ezmessage "$csr"
		fi
	done

	csr=`eval_gettext "Enter description/full name for user \\\${newlirixuser}"`
	ezuserdescription=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "${newlirixuser}")

	ezgroups="uucp,video,audio,storage,games,input"
	csr=`eval_gettext "Do you wish to enable administrative (sudo) privileges for this user?"`
	if ezconfirm "$csr"; then
		ezgroups="wheel,${ezgroups}"
	fi

	csr=`eval_gettext "Enter home directory for user \\\${newlirixuser}"`
	ezhomedir=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "/usr/people/${newlirixuser}")

	csr=`eval_gettext "Do you want this user to be able to login?"`
	if ezconfirm "$csr"; then
		arch-chroot /mnt/lirix useradd -d "$ezhomedir" -mU -G "$ezgroups" -k /etc/skel -c "$ezuserdescription" "$newlirixuser"
	else
		arch-chroot /mnt/lirix useradd -d "$ezhomedir" -mU -G "$ezgroups" -k /etc/skel -c "$ezuserdescription" -s /usr/bin/nologin "$newlirixuser"
	fi

	echo "$newlirixuser:$newlirixpasswd" | chpasswd --root /mnt/lirix
}

ezselectlanguage() {
	languagelist="en_GB.UTF-8*UTF-8 English*(UK) "
	languagelist+="da_DK.UTF-8*UTF-8 Dansk "
	languagelist+="ja_JP.UTF-8*UTF-8 日本語 "
	languagelist+="tr_TR.UTF-8*UTF-8 Türkçe "
	languagelist+="de_DE.UTF-8*UTF-8 Deutsch "
	languagelist+="ar_SA.UTF-8*UTF-8 عربي*(العربية*السعودية) "
	languagelist+="vi_VN*UTF-8 Tiếng*Việt "
	languagelist+=$(cat /etc/locale.gen | grep -Ev '^#\s|^#$' | sed 's/  //' | sed 's/ /*/' | sed 's@#@@g' | awk '1; {printf "-\n"}')
	language=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "josar." 0 0 0 ${languagelist})
	language=$(echo ${language} | sed 's/*/ /')
	sed -i "s/#${language}/${language}/" /etc/locale.gen
	locale-gen
	locale=$(echo ${language} | head -c 5)
	locale+="."
	locale+=$(echo ${language} | awk '{print $NF}')
	export LC_ALL="${locale}"
}

ezselectlanguage
csr=`eval_gettext "Welcome to EZInstall, the installer for Lirix!"`
ezmessage "$csr"
csr=`eval_gettext "Would you like to install Lirix at this moment?"`;
if ! ezconfirm "$csr"; then
	exit 0;
fi

keymaplist=$(localectl list-keymaps | awk '1; {printf "-\n"}')
csr=`eval_gettext "Select your keymap"`
keymap=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 ${keymaplist})
localectl set-keymap "${keymap}"

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop|sr" | tac)
csr=`eval_gettext "Select installation disk"`
if ! device=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 ${devicelist}); then
	exit 1;
else
	csr=`eval_gettext "Do you wish to partition \\\$device?"`
	if ezconfirm "$csr"; then
		csr=`eval_gettext "Do you wish to autopartition \\\$device?"`
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
		csr=`eval_gettext "Select boot partition"`
		bootpartition=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --no-cancel --menu "$csr" 0 0 0 ${partlist})
	fi
	csr=`eval_gettext "Select swap partition"`
	swappartition=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 ${partlist});
	csr=`eval_gettext "Select Lirix partition"`
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
	
	csr=`eval_gettext "Would you like to enter an interactive shell to manually configure more advanced options before proceeding?"`
	if ezconfirmno "$csr"; then
		echo `eval_gettext ">> Entering interactive Bourne Again Shell."`
		echo `eval_gettext ">> The root mountpoint of the Lirix installation is /mnt/lirix"`
		echo `eval_gettext ">> Once complete, return to EZInstall by typing exit."`
		/usr/bin/env PS1="\d \t [EZInstall] (\w) > " /bin/bash --norc -i
	fi
fi

csr=`eval_gettext "Starting installation of Lirix. Setup will continue shortly hereafter."`
ezmessage "$csr"
unsquashfs -f -d /mnt/lirix /opt/lirix/rootfs.squashfs
csr=`eval_gettext "Installation complete. Setup will now continue."`
ezmessage "$csr"
genfstab -U /mnt/lirix >> /mnt/lirix/etc/fstab

cp -pv /etc/X11/xorg.conf.d/00-keyboard.conf /mnt/lirix/etc/X11/xorg.conf.d/00-keyboard.conf
echo "KEYMAP=${keymap}" > /mnt/lirix/etc/vconsole.conf

hostname="3"
while ! [[ "$hostname" =~ ^[a-z-]*$ ]]; do
	csr=`eval_gettext "Enter hostname for system\n(default is apioform-hive)"`
	hostname=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0);
	if ! [[ "$hostname" =~ ^[a-z-]*$ ]]; then
		csr=`eval_gettext "Hostname must only contain lowercase letters or the dash (-) symbol."`
		ezmessage "$csr"
	fi
done

if [[ "$hostname" == "" ]]; then
	hostname="apioform-hive"
fi

lirixuser="3"
while ! [[ "$lirixuser" =~ ^[a-z-]*$ ]]; do
	csr=`eval_gettext "Enter username for main user\n(default is aamoo)"`
	lirixuser=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0);
	if ! [[ "$lirixuser" =~ ^[a-z-]*$ ]]; then
		csr=`eval_gettext "Username must only contain lowercase letters or the dash (-) symbol."`
		ezmessage "$csr"
	fi
done

if [[ "$lirixuser" == "" ]]; then
	lirixuser="aamoo"
fi

lirixpasswd="apa"
lirixpasswdconf="aaa"

while ! [[ "$lirixpasswd" == "$lirixpasswdconf" ]]; do
	csr=`eval_gettext "Enter password for user \\\${lirixuser}\n(default is apioforms)"`
	lirixpasswd=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "$csr" 0 0)
	if [[ "$lirixpasswd" == "" ]]; then
		lirixpasswd="apioforms"
		lirixpasswdconf="apioforms"
		break;
	fi
	csr=`eval_gettext "Me password again."`
	lirixpasswdconf=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --passwordbox "$csr" 0 0)
	if ! [[ "$lirixpasswd" == "$lirixpasswdconf" ]]; then
		csr=`eval_gettext "Passwords do NOT match!!"`
		ezmessage "$csr"
	fi
done

csr=`eval_gettext "Enter description/full name for user \\\${lirixuser}"`
lirixuserdescription=$(dialog --stdout --aspect 120 --backtitle "EZInstall $ezbt" --inputbox "$csr" 0 0 "${lirixuser}")

echo "${hostname}" >> /mnt/lirix/etc/hostname
echo "127.0.0.1		localhost" >> /mnt/lirix/etc/hosts
echo "::1		localhost" >> /mnt/lirix/etc/hosts
echo "127.0.0.1		${hostname}.localdomain		${hostname}" >> /mnt/lirix/etc/hosts

arch-chroot /mnt/lirix useradd -d /usr/people/"$lirixuser" -mU -G wheel,uucp,video,audio,storage,games,input -k /etc/skel -c "$lirixuserdescription" "$lirixuser"
echo "$lirixuser:$lirixpasswd" | chpasswd --root /mnt/lirix

ezaddmoreusers="yes"
while [[ "$ezaddmoreusers" == "yes" ]]; do
	csr=`eval_gettext "Do you wish to add an additional user?"`
	if ezconfirmno "$csr"; then
		ezadduser
	else
		ezaddmoreusers="no"
	fi
done

zonelist=$(find /usr/share/zoneinfo ! -type d | awk '1 ; {printf "-\n"}' | sed 's@/usr/share/zoneinfo/@@g')
csr=`eval_gettext "Select timezone"`
timezone=$(dialog --stdout --aspect 120 --no-cancel --backtitle "EZInstall $ezbt" --menu "$csr" 0 0 0 ${zonelist});

ln -sfv /usr/share/zoneinfo/${timezone} /mnt/lirix/etc/localtime
arch-chroot /mnt/lirix hwclock --systohc

sed -i "s/#${language}.UTF-8 UTF-8/${language}.UTF-8 UTF-8/" /mnt/lirix/etc/locale.gen

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

csr=`eval_gettext "Lirix setup complete. Reboot now?"`
if ezconfirm "$csr"; then
	reboot
fi
