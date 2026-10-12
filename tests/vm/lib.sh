# Shared helpers for the VM tests. Source after setting O (output dir) and QMP (socket path).
# shellcheck shell=bash
n=0
shot() {  # shot NAME "what the screenshot shows"
    n=$((n + 1))
    local f; f=$(printf '%02d-%s.png' "$n" "$1")
    python3 -I tests/vm/qmp.py "$QMP" screendump "$PWD/$O/$f" 2>/dev/null && printf '%s\t%s\n' "$f" "$2" >>"$O/steps.txt"
}
keys() { python3 -I tests/vm/qmp.py "$QMP" keys "$1"; sleep "${2:-0.5}"; }
press() { python3 -I tests/vm/qmp.py "$QMP" press "$@"; sleep 0.6; }
seen() { grep -qaE "$1" "$O/$LOG" 2>/dev/null; }
wait_for() {  # wait_for REGEX SECONDS: text on the serial console
    local i
    for ((i = 0; i < $2; i++)); do seen "$1" && return 0; kill -0 "$QPID" 2>/dev/null || return 1; sleep 1; done
    return 1
}
gold_now() {
    python3 -I tests/vm/qmp.py "$QMP" screendump "$PWD/$O/probe.ppm" 2>/dev/null || { echo 0; return; }
    python3 -I tests/vm/pixels.py "$O/probe.ppm" | sed -E 's/gold=([0-9]+).*/\1/'
}
wait_gold() {  # wait_gold MIN SECONDS: until the screen shows at least MIN gold pixels
    local i
    gold=0
    for ((i = 0; i < $2; i += 2)); do
        sleep 2
        gold=$(gold_now)
        ((gold >= $1)) && return 0
    done
    return 1
}
vm() {  # vm LOG [extra qemu args]: start the VM on $O/disk.qcow2 (NVMe, serial $SERIAL)
    LOG=$1; shift
    qemu-system-x86_64 -L "$OLYMPARCH_QEMU_DATA" -machine q35,accel=kvm -cpu host -smp 4 -m 4096 \
        -drive if=pflash,format=raw,readonly=on,file="$OLYMPARCH_OVMF_CODE" \
        -drive if=pflash,format=raw,file="$O/vars.fd" \
        -drive id=d0,if=none,format=qcow2,file="$O/disk.qcow2" -device nvme,serial="${SERIAL:-OLYTEST1}",drive=d0 \
        -nic user,model=virtio-net-pci -device virtio-vga -display none \
        -serial file:"$O/$LOG" -qmp unix:"$QMP",server=on,wait=off -no-reboot "$@" &
    QPID=$!
    sleep 2
}
stop_vm() { python3 -I tests/vm/qmp.py "$QMP" quit 2>/dev/null; wait "$QPID" 2>/dev/null; }
finish() {
    echo "$1" >"$O/result.txt"
    python3 -I tests/vm/qmp.py "$QMP" quit 2>/dev/null
    echo "${O##*/}: $1"
    [[ $1 == PASS* ]]
    exit
}
unlock_and_desktop() {  # PASSWORD: type it on the Plymouth screen, wait for the desktop
    wait_gold 150 90 || { shot luks-feil "Pikselskjermen for diskpassordet kom ikke"; finish "FAIL · ingen passordskjerm"; }
    keys "$1\n" 1
    wait_for 'login:' 120 || { shot oppstart-feil "Systemet kom ikke opp"; finish "FAIL · systemet kom ikke opp"; }
    wait_gold 300 90 || { shot skrivebord-feil "Skrivebordet kom ikke"; finish "FAIL · skrivebordet kom ikke"; }
    sleep 2
}
