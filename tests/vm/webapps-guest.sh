#!/bin/bash
# Run inside the test VM by tests/vm/webapps (this repo is on /mnt over 9p). Results go to the kernel log as
# «<2>WA: …», which the host reads on the serial console.
#   webapps-guest.sh setup      as root: put olymparch-webapp, the globe, install-app (+ polkit) and the Hyprland
#                               defaults in place, as the ISO + installer would
#   webapps-guest.sh refuse     as the user: bad names and URLs are refused and leave nothing behind
#   webapps-guest.sh added ID   as the user: the .desktop file, its Exec line, icon and list are right
#   webapps-guest.sh window ID  as the user: wait for the web app's window; its class, title and process
#   webapps-guest.sh removed ID as the user: file, icon and profile are gone
set -uo pipefail
src=/mnt
mark() { echo "<2>WA: $*" >/dev/kmsg; }
apps=$HOME/.local/share/applications
store=$HOME/.local/share/olymparch/webapps
case $1 in
setup)
    install -m755 "$src/system/bin/olymparch-webapp" /usr/bin/olymparch-webapp
    install -Dm644 "$src/default/webapps/globe.svg" /usr/share/olymparch/webapps/globe.svg
    install -Dm755 "$src/system/lib/install-app" /usr/lib/olymparch/install-app
    install -m644 "$src/system/polkit/org.olymparch.install-app.policy" /usr/share/polkit-1/actions/
    install -m644 "$src/system/polkit/50-olymparch-install-app.rules" /usr/share/polkit-1/rules.d/
    cp "$src/default/hypr/olymparch.lua" /usr/share/olymparch/hypr/
    cp -r "$src/default/shell/." /usr/share/olymparch/shell/
    cp -r "$src/default/i18n" /usr/share/olymparch/
    systemctl restart polkit
    chmod 666 /dev/kmsg
    command -v chromium >/dev/null && mark "SETUP-CHROMIUM-ALREADY" || mark "SETUP-OK"
    ;;
refuse)
    ok=1
    for u in 'javascript:alert(1)' 'http://www.youtube.com/' 'https://x" ; rm -rf ~' 'file:///etc/passwd' 'https://' \
             'https://a b.com/' "https://x.com/'" 'https://user@x.com/' 'https://x.com/`id`' 'ftp://x.com/' \
             'https://x.com/
Exec=sh'; do
        if olymparch-webapp add Bad "$u" >/dev/null 2>&1 || [ -e "$apps/webapp-bad.desktop" ]; then ok=0; mark "ACCEPTED-URL $u"; fi
    done
    for n in '' '../evil' 'a/b' 'x;rm' "$(printf 'a\nb')" '$(id)' '-----' "$(printf 'n%.0s' {1..41})"; do
        if olymparch-webapp add "$n" https://www.youtube.com/ >/dev/null 2>&1; then ok=0; mark "ACCEPTED-NAME $n"; fi
    done
    [ -z "$(ls -A "$apps" 2>/dev/null | grep '^webapp-')" ] || { ok=0; mark "LEFT-FILES $(ls "$apps")"; }
    [ $ok = 1 ] && mark "REFUSE-OK"
    ;;
added)
    f=$apps/webapp-$2.desktop ok=1
    [ -f "$f" ] || { mark "NO-FILE"; exit 1; }
    grep -qx "Exec=/usr/bin/olymparch-webapp launch $2 \"https://www.youtube.com/\"" "$f" || { ok=0; mark "EXEC $(grep ^Exec= "$f")"; }
    icon=$(sed -n 's/^Icon=//p' "$f")
    [ -s "$icon" ] || { ok=0; mark "NO-ICON $icon"; }
    case $icon in *.png) file -b "$icon" | grep -q '^PNG image data' || { ok=0; mark "BAD-ICON"; } ;; esac
    desktop-file-validate "$f" >/dev/null 2>&1 || { ok=0; mark "INVALID $(desktop-file-validate "$f" 2>&1 | head -n 2)"; }
    olymparch-webapp list | grep "^$2	" >/dev/null || { ok=0; mark "NOT-LISTED"; }
    mark "ICON $icon $(file -b "$icon" | cut -c1-60)"
    [ $ok = 1 ] && mark "ADDED-OK"
    ;;
window)
    # the window's class: webapp-ID on X11, chrome-SITE-webapp-ID on Wayland (= StartupWMClass in the .desktop file)
    want=$(sed -n 's/^StartupWMClass=//p' "$apps/webapp-$2.desktop")
    id=$2
    # (grep reads it all: with pipefail, grep -q would make hyprctl's SIGPIPE the answer)
    has() { hyprctl clients | grep -E "class: (webapp-$id|$want)\$" >/dev/null; }
    for _ in $(seq 300); do has && break; sleep 2; done
    sleep 8   # the page loads
    hyprctl clients | awk '/^Window/ {w = $0} /class:|title:|floating:|fullscreen:|workspace:/ {print w " " $0}' | grep -i -e webapp -e chrom |
        while IFS= read -r l; do mark "CLIENT $l"; done
    if has; then
        pgrep -af chromium | grep -- "--app=https://www.youtube.com/" >/dev/null && pgrep -af chromium | grep -- "--user-data-dir=$store/$2" >/dev/null &&
            [ -d "$store/$2/webapp-$2" ] && mark "WINDOW-OK"
    else
        mark "NO-WINDOW"
    fi
    sleep 15   # pictures of it, then it is closed so the terminal has the keyboard again
    pkill -f -- '--class=webapp-'
    sleep 3
    mark CLOSED
    ;;
removed)
    olymparch-webapp remove "$2" >/dev/null
    [ ! -e "$apps/webapp-$2.desktop" ] && [ ! -e "$store/icons/$2.png" ] && [ ! -e "$store/$2" ] &&
        ! olymparch-webapp list | grep "^$2	" >/dev/null && mark "REMOVED-OK"
    ;;
esac
