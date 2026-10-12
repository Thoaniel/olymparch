#!/bin/bash
# For tests/vm/backgrounds, in the VM (installed as /usr/local/bin/bgt). Answers on the serial console.
#   bgt term         a floating terminal (the old one exits)
#   bgt set N TAG    use background N of the theme in use (answers BG-SET-TAG-OK or -NO)
#   bgt note         two notifications (a normal and a critical one)
#   bgt user         drop pictures of yours (and some that must be skipped) into ~/.config/olymparch/backgrounds
#   bgt remember     the choice is kept per theme across a theme switch
k() { echo "<2>$*" >/dev/kmsg; }
art=/mnt/tests/vm/out/backgrounds-art/user
mine=$HOME/.config/olymparch/backgrounds
case $1 in
term)   # a floating terminal in the middle, so the background shows around it
    hyprctl eval 'hl.window_rule({ name = "bgterm", match = { class = "^bgterm$" }, float = true, center = true, size = "monitor_w*0.52 monitor_h*0.5" })' >/dev/null
    setsid -f foot --app-id bgterm ;;
set)
    if olymparch-theme background set "$2" >/dev/null 2>&1; then k "BG-SET-$3-OK $(olymparch-theme background current)"; else k "BG-SET-$3-NO"; fi ;;
note)
    notify-send 'Steam' 'Hades II er oppdatert · 2 nye prestasjoner'
    notify-send -u critical 'Disk' 'Disken er 95 % full' ;;
user)
    mkdir -p "$mine/hades" "$mine/all"
    cp "$art/Fyrlykt.jpg" "$art/fake.png" "$mine/hades/"
    cp "$art/Skumring.png" "$mine/all/"
    ln -sf /etc/passwd "$mine/hades/lenke.png"
    head -c 21000000 /dev/zero >"$mine/hades/stor.png"
    list=$(olymparch-theme background list | tr -s ' ' | tr '\n' '|')
    k "BG-LIST $list"
    if [[ $list == *"mine:Fyrlykt.jpg"* && $list == *"all:Skumring.png"* && $list != *fake* && $list != *lenke* && $list != *stor* ]]; then
        k "CHK-user-OK"
    else
        k "CHK-user-NO"
    fi ;;
remember)
    olymparch-theme set hades >/dev/null; olymparch-theme background set mine:Fyrlykt.jpg >/dev/null
    olymparch-theme set zeus >/dev/null; olymparch-theme background set all:Skumring.png >/dev/null
    olymparch-settings reset appearance.background@athena >/dev/null   # never chosen: a theme starts on the temple
    olymparch-theme set athena >/dev/null; a0=$(olymparch-theme background current)
    olymparch-theme set hades >/dev/null; a=$(olymparch-theme background current)
    w=$(grep -o '"background": "[^"]*"' ~/.config/olymparch/theme/theme.json)
    olymparch-theme set zeus >/dev/null; b=$(olymparch-theme background current)
    k "BG-REMEMBER athena=$a0 hades=$a ($w) zeus=$b $(grep -o 'appearance.background@[a-z]*": "[^"]*' ~/.config/olymparch/settings.json | tr '\n' ' ')"
    if [ "$a0" = temple ] && [ "$a" = mine:Fyrlykt.jpg ] && [ "$w" = '"background": "mine:Fyrlykt.jpg"' ] && [ "$b" = all:Skumring.png ]; then k "CHK-remember-OK"; else k "CHK-remember-NO"; fi ;;
esac
