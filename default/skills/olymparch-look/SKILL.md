---
name: olymparch-look
description: Use when the user wants Olymparch to look different — another theme, the live wallpaper/background, window gaps, rounding, borders, opacity, blur, font or bar — using the olymparch MCP tools themes_list, theme_set, backgrounds_list, background_set and settings_set.
license: MIT
metadata:
  project: olymparch
---

# Themes and backgrounds

- **Theme** (colours of the shell, lock screen, borders and terminal): `themes_list` shows the themes as JSON with
  the one in use; `theme_set` with an `id` from that list. If `themes_list` says olymparch-theme is missing, the
  system is older: tell the user to update.
- **Background** (the animated temple wallpaper): `backgrounds_list`, then `background_set` with one of the values
  (for example `torch`, `calm` or `off`). «Reduced motion» in Accessibility keeps it still whatever you choose.
- **Details** go through `settings_set` on the `appearance` page: `appearance.gaps_in`, `appearance.gaps_out`,
  `appearance.rounding`, `appearance.border_size`, `appearance.active_opacity`, `appearance.inactive_opacity`,
  `appearance.blur`, `appearance.shadow`, `appearance.font`, `appearance.bar`, `appearance.clock_format`.

Change one thing at a time and ask whether the user likes it before the next; blur and shadows cost GPU time in
games, say so. To check the result, `screenshot` (sensitive: the user approves it) only if the user wants you to look.
