systemctl enable lightdm
systemctl enable NetworkManager
sed -i 's/#greeter-session=example-gtk-greeter/greeter-session=lightdm-gtk-greeter/' /etc/lightdm.conf
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's@export XDG_DATA_DIRS=$MAXX_HOME/share:$XDG_DATA_DIRS@export XDG_DATA_DIRS=$HOME/.maxxdesktop:$XDG_DATA_DIRS:/usr/share:/usr/share/local@' /opt/MaXX/etc/system.desktopenv
