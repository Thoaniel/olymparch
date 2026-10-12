#!/bin/bash
# For tests/vm/themes, in the VM: did theme ID reach every file and Hyprland? Answers on the serial console.
#   theme-check.sh ID BG ACCENT        (BG and ACCENT as rrggbb)
id=$1 bg=$2 accent=$3
t=$HOME/.config/olymparch/theme
if [ "$(olymparch-theme current)" = "$id" ] && grep -q "\"id\": \"$id\"" "$t/theme.json" && grep -qi "background=$bg" "$t/foot.ini" \
    && grep -qi "rgb($accent)" "$t/hypr.lua" && hyprctl getoption general:col.active_border 2>/dev/null | grep -qi "$accent"; then
    echo "<2>CHK-$id-files-OK" >/dev/kmsg
else
    echo "<2>CHK-$id-files-NO $(hyprctl getoption general:col.active_border 2>&1 | tr '\n' ' ')" >/dev/kmsg
fi
