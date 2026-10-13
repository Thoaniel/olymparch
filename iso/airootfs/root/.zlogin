# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh

# Olymparch: the installer starts by itself on the first screen. When it ends without installing (cancelled or
# failed), a small menu offers to start it again, shut down or restart; the command line is the last choice.
# The VM tests drive the console themselves: they set the QEMU firmware file opt/olymparch/manual.
olymparch_manual() { modprobe -q qemu_fw_cfg 2>/dev/null; [ -e /sys/firmware/qemu_fw_cfg/by_name/opt/olymparch/manual ]; }
if [ "$(tty)" = /dev/tty1 ] && [ -z "${OLYMPARCH_SETUP_STARTED:-}" ] && ! olymparch_manual; then
    export OLYMPARCH_SETUP_STARTED=1
    while true; do
        olymparch-setup
        choice=$(whiptail --title Olymparch --nocancel --menu \
            "The installer stopped. / Installasjonen stoppet." 15 64 4 \
            again "Start the installer again / Start på nytt" \
            off "Shut down / Slå av" \
            reboot "Restart / Start PC-en på nytt" \
            shell "Command line (advanced) / Kommandolinje" 3>&1 1>&2 2>&3) || choice=again
        case $choice in
            off) systemctl poweroff ;;
            reboot) systemctl reboot ;;
            shell) break ;;
        esac
    done
fi
