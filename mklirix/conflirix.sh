systemctl enable lightdm
systemctl enable NetworkManager
systemctl enable cups
sed -i 's/#greeter-session=example-gtk-greeter/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/GRUB_DISTRIBUTOR="Arch"/GRUB_DISTRIBUTOR="Lirix"/' /etc/default/grub
sed -i 's/OS="${GRUB_DISTRIBUTOR} Linux"/OS="${GRUB_DISTRIBUTOR}"/' /etc/grub.d/10_linux
sed -i 's@export XDG_DATA_DIRS=$MAXX_HOME/share:$XDG_DATA_DIRS@export XDG_DATA_DIRS=$HOME/.maxxdesktop:$XDG_DATA_DIRS:/usr/share:/usr/share/local@' /opt/MaXX/etc/system.desktopenv
pacman -R gdm gnome-shell gnome-session
