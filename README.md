# Olymparch

An Arch Linux distribution for gaming, built around Hyprland and the optional AI assistant Olympus/Zeus.
Work in progress. Nothing here is released yet.

- `iso/` – the archiso profile for the installer ISO
- `bin/` – `olymparch-*` commands
- `art/` – generators for the wallpaper (`minimal.py`) and the animated torch wallpaper (`torch.py`)
- `tests/vm/` – QEMU tests that install from the ISO and check the result
- `dev/fetch-tools` + `dev/env` – fetch QEMU, OVMF and archiso as verified Arch packages into ~/.local/opt, no root
