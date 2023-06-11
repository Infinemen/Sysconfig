#! /bin/bash
# ICONS 部分特殊的标记图标 这里是我自己用的，你用不上的话去掉就行
tempfile=$(cd $(dirname $0);cd ..;pwd)/temp

this=_icons
color="^c#2D1B46^^b#5555660x66^"
signal=$(echo "^s$this^" | sed 's/_//')

with_v2raya() {
    [ "$(ps aux | grep -v grep | grep 'v2raya')" ] && icons=(${icons[@]} " 󱨑  ")
}

with_bluetooth() {
    [ ! "$(command -v bluetoothctl)" ] && echo command not found: bluetoothctl && return
    [ "$(bluetoothctl info 88:C9:E8:14:2A:72 | grep 'Connected: yes')" ] && icons=(${icons[@]} "  ")
}
update() {
    icons=(" ")
    with_v2raya
    text=" ${icons[@]} "
    sed -i '/^export '$this'=.*$/d' $DWM/statusbar/temp
    printf "export %s='%s%s%s'\n" $this "$signal" "$color" "$text" >> $tempfile
}

notify() {
    texts=""
    [ "$(ps aux | grep -v grep | grep 'v2raya')" ] && texts="$texts\n 󱨑 v2raya  已启动"
    [ "$(bluetoothctl info 88:C9:E8:14:2A:72 | grep 'Connected: yes')" ] && texts="$texts\n WH-1000XM4 已链接"
    [ "$texts" != "" ] && notify-send "  Info" "$texts" -r 9527
}

call_menu() {
    case $(echo -e ' 关机\n 重启\n󰒲 休眠\n 锁定' | rofi -dmenu -window-title power ) in
        " 关机") poweroff ;;
        " 重启") reboot ;;
        "󰒲 休眠") systemctl hibernate ;;
        " 锁定") betterlockscreen -l blur ;;
    esac
}

click() {
    case "$1" in
        L) notify; ;;
        R) call_menu ;;
    esac
}

case "$1" in
    click) click $2 ;;
    notify) notify ;;
    *) update ;;
esac
