#!/bin/sh

# mklirix utility, will build Lirix by 
# installing the latest packages specified in the packages file

rootfsdir="target/rootfs"
lirixvirtfs="target/rootfs.img"
lirixsquashfs="target/rootfs.squashfs"

log() {
	echo "[MKLIRIX]" $1
}

cleanTarget() {
	if [ -d $rootfsdir ]; then
		log "Purging Target RootFS Directory";
		rm -rfv $rootfsdir
	fi

	if [ -f $lirixvirtfs ]; then
		log "Purging Target Virtual Filesystem for Lirix";
		rm -fv $lirixvirtfs
	fi

	if [ -f $lirixsquashfs ]; then
		log "Purging Target RootFS SquashFS for Lirix";
		rm -fv $lirixsquashfs
	fi
}

ensureGoodEnvironment() {
	if [ ! -f "pacman.conf" ]; then
		log "No pacman configuration file found; will not make Lirix here!";
		exit;
	fi

	if [ ! -f "packages" ]; then
		log "No package list for Lirix found; will not make Lirix here!";
		exit;
	fi

	if [ ! -f "conflirix.sh" ]; then
		log "No conflirix found; will not make Lirix here!";
		exit;
	fi

	if [ ! -d "target" ]; then
		log "Creating Target Directory"
		mkdir -pv "target"
	fi
}


createRootFS() {
	log "Creating new Target Virtual Filesystem for Lirix";
	fallocate -l 8G $lirixvirtfs
	mkfs.ext4 $lirixvirtfs

	log "Mounting Target Virtual Filesystem for Lirix";
	mkdir -pv $rootfsdir
	mount -v $lirixvirtfs $rootfsdir
}

unmountRootFS() {
	log "Unmounting Lirix RootFS";
	umount -v $rootfsdir
}

strapLirix() {
	log "Strapping Lirix packages to Lirix RootFS";

	if pacstrap -C pacman.conf -c $rootfsdir $(<packages); then
		log "Lirix packages strapped successfully to Lirix RootFS";
	else
		log "Could not strap Lirix packages; will cease to make Lirix here!";
		unmountRootFS;
		exit;
	fi

	cp -v pacman.conf $rootfsdir/etc/pacman.conf
}

configureLirix() {
	log "Executing conflirix in Lirix RootFS Changed Root";
	cp ./conflirix.sh $rootfsdir/conflirix.sh
	arch-chroot $rootfsdir sh /conflirix.sh
	rm -v $rootfsdir/conflirix.sh
}

squashLirix() {
	log "Squashing Lirix RootFS";
	mksquashfs $rootfsdir $lirixsquashfs
}

if [ "$EUID" -ne 0 ]; then
	log "mklirix MUST be executed as a root user"
	exit;
fi

ensureGoodEnvironment;
cleanTarget;
createRootFS;
strapLirix;
configureLirix;
squashLirix;
unmountRootFS;

log "Lirix has been successfully made, do with the files in the target directory whatever you want.";

