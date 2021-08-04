#!/bin/sh
# Synchronises any new recommended packages to Lirix.

pkglist=`cat mklirix/packages`
srpconf() {
	$(dialog --stdout --aspect 120 --backtitle "Lirix Maintenance" --yesno "$@" 0 0)
}

if [ "$EUID" -ne 0 ]; then
	echo "Root privileges are required."
	exit 121;
fi

if srpconf "Synchronise the following packages?\n$pkglist"; then
	if srpconf "It is recommended to firstly upgrade the system. Do so?"; then
		pacman -Syu
	fi
	pacman -S $(<mklirix/packages);
	pacman -R --noconfirm gdm gnome-shell gnome-session
fi;

echo "Package synchronisation complete. No packages were removed."
