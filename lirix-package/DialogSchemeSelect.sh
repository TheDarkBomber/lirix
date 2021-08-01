#!/bin/sh
# SGI Scheme Selector using Dialog

updateScheme() {
	killall -SIGTERM toolchest > /dev/null
	$MAXX_HOME/bin/update-desktop
	$MAXX_HOME/bin/tellwm fast_restart
	exec $MAXX_BIN/toolchest -geometry +33+152 >> $HOME/.console &
}

darkScheme() {
	echo "$1" > $HOME/.maxxdesktop/SgiDarkScheme
}

selectScheme() {
	echo "$1" > $HOME/.maxxdesktop/MAXX_THEME
	updateScheme
}

updateCurrent() {
	sed -i "s/_(current)//" /opt/MaXX/etc/schemelist
	sed -i "s/${schemeSelected}/${schemeSelected}_(current)/" /opt/MaXX/etc/schemelist
}

schemeList=`cat /opt/MaXX/etc/schemelist`
schemeSelected=$(dialog --stdout --aspect 120 --backtitle "Caesar's Scheme Selector" --menu "Select SGI Scheme" 0 0 0 ${schemeList})

case $schemeSelected in
		Arizona)
			darkScheme "True"
			selectScheme "Arizona"
			updateCurrent
			exit
			;;
		Bayou)
			darkScheme "True"
			selectScheme "Bayou"
			updateCurrent
			exit
            ;;
		BlackAndWhite)
			darkScheme "False"
			selectScheme "BlackAndWhite"
			updateCurrent
			exit
			;;
		Buckingham)
			darkScheme "True"
			selectScheme "Buckingham"
			updateCurrent
			exit
			;;
		DarkBliss)
			darkScheme "True"
			selectScheme "DarkBliss"
			updateCurrent
			exit
            ;;
		Gainsborough)
			darkScheme "False"
			selectScheme "Gainsborough"
			updateCurrent
			exit
			;;
		Gotham)
			darkScheme "True"
			selectScheme "Gotham"
			updateCurrent
			exit
			;;
		GrayScale)
			darkScheme "False"
			selectScheme "GrayScale"
			updateCurrent
			exit
            ;;
		IndigoMagic)
			darkScheme "False"
			selectScheme "IndigoMagic"
			updateCurrent
			exit
			;;
		Inverness)
			darkScheme "False"
			selectScheme "Inverness"
			updateCurrent
			exit
			;;
		KeyWest)
			darkScheme "False"
			selectScheme "KeyWest"
			updateCurrent
			exit
            ;;
		Lascaux)
			darkScheme "False"
			selectScheme "Lascaux"
			updateCurrent
			exit
			;;
		Leonardo)
			darkScheme "True"
			selectScheme "Leonardo"
			updateCurrent
			exit
			;;
		Mendocino)
			darkScheme "True"
			selectScheme "Mendocino"
			updateCurrent
			exit
            ;;
		Metropolis)
			darkScheme "True"
			selectScheme "Metropolis"
			updateCurrent
			exit
			;;
		Milan)
			darkScheme "False"
			selectScheme "Milan"
			updateCurrent
			exit
			;;
		Monet)
			darkScheme "False"
			selectScheme "Monet"
			updateCurrent
			exit
            ;;
		Pacific)
			darkScheme "True"
			selectScheme "Pacific"
			updateCurrent
			exit
			;;
		Potrero)
			darkScheme "False"
			selectScheme "Potrero"
			updateCurrent
			exit
			;;
		Print)
			darkScheme "False"
			selectScheme "Print"
			updateCurrent
			exit
            ;;
		RedGreenSafe)
			darkScheme "False"
			selectScheme "RedGreenSafe"
			updateCurrent
			exit
			;;
		Rembrandt)
			darkScheme "True"
			selectScheme "Rembrandt"
			updateCurrent
			exit
			;;
		Rio)
			darkScheme "True"
			selectScheme "Rio"
			updateCurrent
			exit
            ;;
		RoseGarden)
			darkScheme "False"
			selectScheme "RoseGarden"
			updateCurrent
			exit
			;;
		Sargent)
			darkScheme "True"
			selectScheme "Sargent"
			updateCurrent
			exit
			;;
		Titian)
			darkScheme "False"
			selectScheme "Titian"
			updateCurrent
			exit
           	;;
		Turner)
			darkScheme "True"
			selectScheme "Turner"
			updateCurrent
			exit
			;;
		Vancouver)
			darkScheme "False"
			selectScheme "Vancouver"
			updateCurrent
			exit
			;;
		VanGogh)
			darkScheme "True"
			selectScheme "VanGogh"
			updateCurrent
			exit
            ;;
		Whistler)
			darkScheme "True"
			selectScheme "Whistler"
			updateCurrent
			exit
			;;
		Willis)
			darkScheme "False"
			selectScheme "Willis"
			updateCurrent
			exit
			;;
		*)
			exit 0
			;;
esac