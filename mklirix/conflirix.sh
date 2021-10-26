systemctl enable lightdm
systemctl enable NetworkManager
systemctl enable cups
systemctl enable lirixgttab.tty1
systemctl enable lirixgttab.tty2
systemctl enable lirixgttab.tty3
systemctl enable lirixgttab.tty4
systemctl enable lirixgttab.tty5
systemctl enable lirixgttab.tty6
sed -i 's/#greeter-session=example-gtk-greeter/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/GRUB_DISTRIBUTOR="Arch"/GRUB_DISTRIBUTOR="Lirix"/' /etc/default/grub
sed -i 's/OS="${GRUB_DISTRIBUTOR} Linux"/OS="${GRUB_DISTRIBUTOR}"/' /etc/grub.d/10_linux
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
sed -i 's@#background=@background=/opt/MaXX/share/wallpapers/sgi-startup-bg.png@' /etc/lightdm/lightdm-gtk-greeter.conf
sed -i 's@export XDG_DATA_DIRS=$MAXX_HOME/share:$XDG_DATA_DIRS@export XDG_DATA_DIRS=$HOME/.maxxdesktop:$XDG_DATA_DIRS:/usr/share:/usr/share/local@' /opt/MaXX/etc/system.desktopenv
