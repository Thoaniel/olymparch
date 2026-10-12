---
name: olymparch-troubleshooting
description: Use when something is wrong on the user's Olymparch PC — no sound, a missing bar, a game that won't start, no network, a full disk, a broken update, slow performance, a driver problem. Start with the olymparch MCP tool system_doctor, then hardware_plan, settings and snapshots.
license: MIT
metadata:
  project: olymparch
---

# Troubleshooting with doctor

1. **`system_doctor` first.** One line per check: ✓ fine, ✗ a problem (Hyprland, the shell, idle/lock, PipeWire,
   settings, free space, snapshots, NetworkManager, failed system services). Read the ✗ lines to the user.
2. **Look closer, read-only:**
   - drivers and hardware: `hardware_plan`;
   - sound: `volume_get`, `settings_list audio`;
   - screens: `settings_list display`;
   - space: `system_info`, and `snapshots_list` (snapshots use space too);
   - games: `games_list`, `settings_list games`.
3. **Fix with the user, one step at a time**, through the tools (`settings_set`, `settings_reset` to undo a change
   of yours). Each change shows a card; explain first what it does and how to undo it.
4. **What you leave to the user** (say so, and how): failed system services (`systemctl --failed` in a terminal),
   driver installs (Settings → Hardware → «Install offered drivers»), disk clean-up (Settings → Disks →
   «Clean up»), and rolling back (`rollback_open`). Never `sudo`.
5. If the shell or Hyprland itself is down, the tools that need them fail: say what failed and suggest logging out
   and in again before anything bigger.

Report back briefly: what you checked, what you found, what you changed, what is left for the user.
