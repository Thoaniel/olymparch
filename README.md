# Olymparch

An Arch Linux distribution for gaming: Hyprland with its own Quickshell desktop, set up so that games, hardware
and everyday events just work, with the optional local AI assistant Olympus/Zeus.

**Status:** pre-release. Built and tested in QEMU (see `tests/vm/`); the first stable ISO comes when the
hardware tests on real machines are done.

## What you get

- **Installer** – a short guided setup (language, keyboard with a test field, time zone, network, disk, user,
  options). The disk is always encrypted (LUKS2); the same password unlocks the disk and the user, and the
  installer shows a recovery key. Options: Games (on), Emulators, Zeus, Discord, Spotify, OBS, Code, and
  hibernation on laptops.
- **Boot** – a styled Limine menu and an animated Plymouth screen; unlocking the disk flows straight into the
  desktop.
- **Desktop** – Hyprland, a bar, an app launcher (Super+Space), notifications with action buttons, a volume
  display, its own lock screen (Super+L, and after 10 minutes idle) and an animated wallpaper that pauses when
  windows cover it or a game runs.
- **Settings** (Super+comma) – one window for everything, with a simple and an advanced view. Every setting is
  remembered. The same settings are available on the command line: `olymparch-settings`.
- **Snapshots** – btrfs + snapper. Every package change makes a snapshot, and the boot menu lists them, so a
  broken update is one reboot away from undone (`olymparch-rollback`).
- **Hardware** – `olymparch-hw` reads what the machine has and offers the right drivers and firmware with one
  click, also for devices plugged in later (Xbox controllers, racing wheels, …).
- **Games** – Steam, Heroic and emulators as installer options; game mode and the right Proton version for every
  game automatically; MangoHud ready but hidden (Shift+F12).
- **Events** – downloads are virus-checked, archives unpack with one click, USB disks mount with a notification,
  a nearly full disk offers a cleanup that shows what it frees before anything is deleted.

Hardware: AMD and Intel graphics on desktops and laptops. NVIDIA (including hybrid laptops) and laptops in
general are beta. No dual boot in v1, and Secure Boot must be off.

## Keys

| Keys | Action |
|---|---|
| Super+Space | App launcher |
| Super+Return | Terminal (foot) |
| Super+Q | Close window |
| Super+V | Float window |
| Super+1…9 | Workspace |
| Super+L | Lock |
| Super+comma | Settings |
| Super+Shift+M | Log out |
| Shift+F12 | Show/hide MangoHud in games |

## Commands

| Command | What it does |
|---|---|
| `olymparch update` | Update the system (with a snapshot first) |
| `olymparch-rollback` | Go back to a snapshot |
| `olymparch-settings` | Read and change settings |
| `olymparch-hw` | Show detected hardware and offered drivers |
| `olymparch-cleanup` | Free disk space, asking per item |
| `olymparch-doctor` | Health check |

## Repository

- `iso/` – the archiso profile for the installer ISO
- `bin/` – the installer (`olymparch-setup` asks, `olymparch-install` installs from an answers file)
- `system/` – commands, pacman hooks and services installed on the system
- `default/` – Hyprland config, the Quickshell desktop and lock screen, Plymouth theme, i18n, settings schema,
  hardware rules, game config
- `art/` – generators for the wallpaper frames and the boot art
- `tests/vm/` – QEMU tests that install from the ISO and check the result with a screenshot of every step
- `dev/fetch-tools`, `dev/env`, `dev/build-iso` – build and test without root

## Building

Everything runs as a normal user (no sudo): the tools come as verified Arch packages unpacked into
`~/.local/opt/olymparch-tools`.

```sh
dev/fetch-tools          # once: QEMU, OVMF, archiso, …
dev/build-iso            # → out/olymparch-*.iso
tests/vm/install-disk    # install the ISO into a VM and boot it
```

Other tests reuse an installed disk: `OLYMPARCH_BASE=<dir with disk.qcow2 + vars.fd> tests/vm/<test>`.
Each test writes screenshots, `steps.txt` and `result.txt` to `tests/vm/out/<test>/`, and
`tests/vm/report.py` makes an HTML report of them.

## Privacy

No telemetry. Zeus runs locally and changes settings only after you approve. Bugs and ideas: GitHub Issues.
