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

if [ -f $HOME/.maxxdesktop/MAXX_THEME ]; then
	currentScheme=`cat $HOME/.maxxdesktop/MAXX_THEME`
else
	currentScheme=`IndigoMagic`
fi

schemeList=`cat /opt/MaXX/etc/schemelist`
schemeList=$(echo $schemeList | sed "s/${currentScheme}/${currentScheme}_(current)/")

schemeSelected=$(dialog --stdout --aspect 120 --backtitle "Caesar's Scheme Selector" --menu "Select SGI Scheme" 0 0 0 ${schemeList})

case $schemeSelected in
		Arizona)
			darkScheme "True"
			selectScheme "Arizona"
			exit
			;;
		Bayou)
			darkScheme "True"
			selectScheme "Bayou"
			exit
            ;;
		BlackAndWhite)
			darkScheme "False"
			selectScheme "BlackAndWhite"
			exit
			;;
		Buckingham)
			darkScheme "True"
			selectScheme "Buckingham"
			exit
			;;
		DarkBliss)
			darkScheme "True"
			selectScheme "DarkBliss"
			exit
            ;;
		Gainsborough)
			darkScheme "False"
			selectScheme "Gainsborough"
			exit
			;;
		Gotham)
			darkScheme "True"
			selectScheme "Gotham"
			exit
			;;
		GrayScale)
			darkScheme "False"
			selectScheme "GrayScale"
			exit
            ;;
		IndigoMagic)
			darkScheme "False"
			selectScheme "IndigoMagic"
			exit
			;;
		Inverness)
			darkScheme "False"
			selectScheme "Inverness"
			exit
			;;
		KeyWest)
			darkScheme "False"
			selectScheme "KeyWest"
			exit
            ;;
		Lascaux)
			darkScheme "False"
			selectScheme "Lascaux"
			exit
			;;
		Leonardo)
			darkScheme "True"
			selectScheme "Leonardo"
			exit
			;;
		Mendocino)
			darkScheme "True"
			selectScheme "Mendocino"
			exit
            ;;
		Metropolis)
			darkScheme "True"
			selectScheme "Metropolis"
			exit
			;;
		Milan)
			darkScheme "False"
			selectScheme "Milan"
			exit
			;;
		Monet)
			darkScheme "False"
			selectScheme "Monet"
			exit
            ;;
		Pacific)
			darkScheme "True"
			selectScheme "Pacific"
			exit
			;;
		Potrero)
			darkScheme "False"
			selectScheme "Potrero"
			exit
			;;
		Print)
			darkScheme "False"
			selectScheme "Print"
			exit
            ;;
		RedGreenSafe)
			darkScheme "False"
			selectScheme "RedGreenSafe"
			exit
			;;
		Rembrandt)
			darkScheme "True"
			selectScheme "Rembrandt"
			exit
			;;
		Rio)
			darkScheme "True"
			selectScheme "Rio"
			exit
            ;;
		RoseGarden)
			darkScheme "False"
			selectScheme "RoseGarden"
			exit
			;;
		Sargent)
			darkScheme "True"
			selectScheme "Sargent"
			exit
			;;
		Titian)
			darkScheme "False"
			selectScheme "Titian"
			exit
           	;;
		Turner)
			darkScheme "True"
			selectScheme "Turner"
			exit
			;;
		Vancouver)
			darkScheme "False"
			selectScheme "Vancouver"
			exit
			;;
		VanGogh)
			darkScheme "True"
			selectScheme "VanGogh"
			exit
            ;;
		Whistler)
			darkScheme "True"
			selectScheme "Whistler"
			exit
			;;
		Willis)
			darkScheme "False"
			selectScheme "Willis"
			exit
			;;
		*)
			exit 0
			;;
esac