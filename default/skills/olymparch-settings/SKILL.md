---
name: olymparch-settings
description: Use when the user wants to change or check an Olymparch setting — display scale or refresh rate, sound output, keyboard layout, notifications and do-not-disturb, power and lock times, accessibility, privacy, update time — through the olymparch MCP tools settings_list, settings_get and settings_set.
license: MIT
metadata:
  project: olymparch
---

# Olymparch settings

Every setting has a key like `appearance.gaps_in`, a page, a type and limits, all in the schema (resource
`olymparch://settings/schema`). Values live in `~/.config/olymparch/settings.json`, but **never edit that file**:
`settings_set` validates and applies (Hyprland, the shell, PipeWire …) in one go.

## How to change one

1. Find the key: `settings_list` with `page` (display, audio, input, network, bluetooth, power, disks, hardware,
   games, zeus, events, apps, account, keyboard, appearance, notifications, accessibility, privacy, updates, backup,
   about), or search the schema resource.
2. `settings_get` the current value and tell the user what it is now.
3. `settings_set` with the value as text: `on`/`off` for switches, digits for numbers, one of the options for
   choices. Per monitor: `display.scale@DP-1` (monitor names from `settings_list display`).
4. The user approves the card. If the result is an error, read it: it names the allowed range or options.

Examples: `notifications.dnd = on`, `appearance.gaps_in = 8`, `display.scale@DP-1 = 1.25`,
`keyboard.layout = no`, `power.profile = performance`.

## Not through you

`ai.*` (your own permissions), `account.*`, `backup.*`, `apps.terminal` and the user's own shortcuts are refused.
Settings that need the system (`/etc`) ask the user for their password themselves. Actions (buttons such as
«Update now») are not settings: use the matching tool (`update_open`, `rollback_open` …).
