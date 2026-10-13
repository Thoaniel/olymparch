#!/bin/bash
# Run as the user inside the VM installed by tests/vm/apps-install (this repo on /mnt over 9p): checks of the
# «More apps and tools» options. Results go to the kernel log as «<2>CHK: …» (/dev/kmsg is opened up first).
set -uo pipefail
mark() { echo "<2>CHK: $*" >/dev/kmsg; }
pk=(lutris moonlight-qt prismlauncher chromium obsidian neovim helix zed fzf zoxide ripgrep starship btop lazygit
    lazydocker alacritty kitty ghostty)
pacman -Q "${pk[@]}" >/dev/null && mark PKGS-OK || mark "PKGS-MISSING $(pacman -Q "${pk[@]}" 2>&1 | grep -o "'[^']*'" | tr '\n' ' ')"
# nothing that was not ticked
pacman -Q steam discord code obs-studio >/dev/null 2>&1 || mark LEAN-OK
# LocalSend (ticked) comes from Olymparch's own repo: installed and signed when [olymparch] is online
grep -q '^\[olymparch\]' /etc/pacman.conf && pacman -Q localsend-bin >/dev/null 2>&1 && mark LOCALSEND-OK
[ -f /etc/xdg/nvim/init.lua ] && [ "$(nvim --headless +'lua io.write(tostring(vim.o.number) .. vim.g.mapleader)' +qa 2>&1)" = "true " ] && mark NVIM-OK
# a new interactive bash (as a terminal starts it): z, starship and fzf's Ctrl+R are on
out=$(bash -ic 'type -t z; echo "$STARSHIP_SHELL"; type -t __fzf_history__' 2>/dev/null | tr '\n' ' ')
mark "SHELL $out"
[ "$out" = "function bash function " ] && grep -q olymparch-shell-tools.sh ~/.bashrc && mark SHELL-OK
ok=1
for w in xbox-cloud-gaming geforce-now; do
    f=$HOME/.local/share/applications/webapp-$w.desktop
    [ -f "$f" ] && grep -q "^Exec=/usr/bin/olymparch-webapp launch $w \"https://" "$f" && desktop-file-validate "$f" >/dev/null || ok=0
    mark "WEBAPP $w $(sed -n 's/^Icon=//p' "$f" 2>/dev/null)"
done
[ $ok = 1 ] && mark CLOUD-OK
mark DONE
