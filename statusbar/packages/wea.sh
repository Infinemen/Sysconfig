#!/bin/sh
#curl -s 'wttr.in/hefei?format=%c+%t+%m'

this=_wea
text_color="^c#4B005B^^b#7E51680x99^"
signal=$(echo "^s$this^" | sed 's/_//')

update() {
    wea_icon=""
    wea_text1=$(curl -s 'wttr.in/hefei?format=%c+%t' | tr -d " ")
    wea_text2=$(curl -s 'wttr.in/hefei?format=%m' | tr -d " ")
    temp_text=$(sensors | grep Tctl | awk '{printf "%d°C", $2}')

    text=" $wea_text1 $wea_text2 "

    sed -i '/^export '$this'=.*$/d' $DWM/statusbar/temp
    printf "export %s='%s%s%s%s%s'\n" $this "$signal" "$text_color" "$text" >> $DWM/statusbar/temp
}

long_wea() {
    pid1=`ps aux | grep 'st -t statusutil' | grep -v grep | awk '{print $2}'`
    pid2=`ps aux | grep 'st -t statusutil_cpu' | grep -v grep | awk '{print $2}'`
    mx=`xdotool getmouselocation --shell | grep X= | sed 's/X=//'`
    my=`xdotool getmouselocation --shell | grep Y= | sed 's/Y=//'`
    kill $pid1 && kill $pid2 || st -t weather -g 82x25+$((mx - 328))+$((my + 20)) -c FGN -e curl -s 'wttr.in/dalian' >> echo
}

click() {
	case "$1" in
		L) update ;;
		R) long_wea;;
	esac
}

case "$1" in
    click) click $2 ;;
    notify) notify ;;
    *) update ;;
esac
