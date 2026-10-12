---
name: olymparch
description: Use when the user asks you to look at or change anything on their Olymparch PC (Arch Linux gaming desktop on Hyprland) — settings, theme, wallpaper, windows, apps, sound, notifications, packages, updates, games, reminders, files in their home folder, or "what is wrong with my PC". Explains the olymparch MCP server and the safety rules.
license: MIT
metadata:
  project: olymparch
  server: olymparch-mcp
---

# Olymparch

Olymparch is the user's own PC: Arch Linux, Hyprland, a gold-on-black shell with a bar, a menu (Super+Space) and
Settings (Super+comma). One person uses it. You control it through the **olymparch MCP server**
(`/usr/bin/olymparch-mcp`, server name `olymparch`).

## Always

1. **Use the MCP tools, not shell commands.** If the `olymparch` tools are available, use them even when you also
   have a shell. They validate every value, and the user sees exactly what you do.
2. **Never use `sudo`, `pkexec` or `pacman` yourself**, never edit files under `/etc` or `~/.config/olymparch` by
   hand. System changes go through the tools; the ones that need a password open a terminal for the user.
3. **Ask before you act** when the request is vague. Say in one sentence what you are about to change.
4. **Approval cards.** Tools marked `[change]` or `[sensitive]` show the user a card on their screen
   («Tillat én gang» / «Alltid for …» / «Avvis», 60 s). Tell the user to look at the screen. If the result says
   *denied*, stop: do not retry the same call, ask the user in the chat what they want instead. During a game the
   card is never shown and calls are denied: wait until the user is back.
5. **Read before you write.** `settings_get` / `settings_list` first, then `settings_set`; read the resource
   `olymparch://settings/schema` for valid values.
6. Things you can't do on purpose: change Settings → AI agents, accounts, backups, the terminal or your own
   shortcuts; read hidden files (`.ssh`, `.config`, …) or key/password files; press buttons on the approval card.
   Don't look for ways around this.

## The tools by area

| Area | Read (no card) | Change / sensitive (card) |
|---|---|---|
| System | `system_info`, `system_doctor`, `hardware_plan` | – |
| Settings | `settings_list`, `settings_get` | `settings_set`, `settings_reset` |
| Look | `themes_list`, `backgrounds_list` | `theme_set`, `background_set` |
| Windows | `windows_list`, `workspaces_list` | `window_focus`, `window_move`, `window_close`, `workspace_focus` |
| Apps | `apps_list`, `webapps_list` | `app_launch`, `webapp_add`, `webapp_remove` |
| Sound & media | `volume_get` | `volume_set`, `media_control` |
| Notifications | `reminders_list` | `notification_send`, `reminder_add`, `reminder_cancel` |
| Screen | – | `screenshot`, `ocr_screen` (sensitive), `colour_pick` |
| Clipboard | – | `clipboard_read` (sensitive) |
| Packages | `packages_search`, `packages_catalog`, `updates_check` | `package_install` (sensitive), `package_remove`, `update_open` |
| Snapshots | `snapshots_list` | `rollback_open` |
| Games | `games_list` | `game_add` |
| Files (home only) | `files_list` | `files_read` (sensitive) |

More detail: the skills `olymparch-settings`, `olymparch-look`, `olymparch-windows-apps`, `olymparch-packages`
and `olymparch-troubleshooting`.

## If the tools are missing

The server may be switched off (Settings → AI agents) or not registered. Tell the user; they can run
`olymparch-mcp register` or press «Registrer nå» on that page. Don't fall back to `sudo` or editing config files.
