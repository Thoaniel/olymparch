---
name: olymparch-packages
description: Use when the user wants to install, remove or update software on Olymparch, look for a package, or check for updates — with the olymparch MCP tools packages_catalog, package_install, packages_search, package_remove, updates_check and update_open. Never run pacman, yay or sudo yourself.
license: MIT
metadata:
  project: olymparch
---

# Packages and updates

Olymparch is Arch Linux, but **you never run `pacman`, `yay`, `paru` or `sudo`**. The user stays in control:

- **Optional apps** (Lutris, Moonlight, Discord, OBS, Steam extras, editors, terminals …):
  `packages_catalog` lists them with an app id and whether they are installed. `package_install` with that app id
  is the menu's Install button (official repositories only, a snapshot is taken first). It is *sensitive*: the user
  approves the card. You cannot install arbitrary package names.
- **Anything else**: `packages_search` finds it; then tell the user the exact command and let them decide, or use
  the catalog when it is there. Prefer Flatpak or the catalog over the AUR, and never suggest disabling signatures.
- **Remove**: `package_remove` opens a terminal with `sudo pacman -Rs PACKAGE`; the user reads the list and types
  their password there.
- **Updates**: `updates_check` (read-only, nothing changes). To update, `update_open` opens a terminal with
  `olymparch update` (snapshot first, it asks before installing). Never during a game.
- **Something broke after an update**: `snapshots_list`, then `rollback_open` opens a terminal where the user picks
  a snapshot; it becomes the system after a restart, and the old one is kept.
