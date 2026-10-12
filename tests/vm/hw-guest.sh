#!/bin/bash
# Run as root inside the test VM by tests/vm/hw: put this repo's olymparch-hw pieces in place (the repo is on
# /mnt over 9p), as the ISO + installer would, plus the test-only hotplug rule. Marks progress in the kernel
# log, which the host reads on the serial console.
set -euo pipefail
src=/mnt
share=/usr/share/olymparch
mark() { echo "<2>$*" >/dev/kmsg; }
mkdir -p "$share/hw"
cp -r "$src/default/hw/." "$share/hw/"
rm -rf -- "$share/system"
cp -r "$src/system" "$share/"
cp -r "$src/default/shell/." "$share/shell/"   # the base disk may have an older shell
cp -r "$src/default/i18n" "$share/"
cp "$src/default/hypr/olymparch.lua" "$share/hypr/"
install -Dm644 "$src/tests/vm/hw-hotplug.rule" /etc/olymparch/hw/rules.d/vm-hotplug.rule
"$share/system/bin/olymparch-hw" setup-system
# the user manager needs the new user units
systemctl --user -M zeus@ daemon-reload 2>/dev/null || runuser -u zeus -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user daemon-reload
mark "HW-READY $(olymparch-hw plan --list rules | paste -sd' ')"
