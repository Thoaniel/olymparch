# Themes

One theme is the whole look of Olymparch: the bar, the menu, notifications, the volume OSD, the Settings window,
the theme picker, the lock screen, the Hyprland window borders, the foot terminal and the animated temple wallpaper.
Olymparch ships a theme for each of the gods of Olympus, with Zeus (black and gold) as the default:

| id | God | Look |
|---|---|---|
| `zeus` | Zeus | black marble, gold and lightning (default) |
| `hera` | Hera | royal indigo and peacock blue |
| `poseidon` | Poseidon | deep water and sea-foam teal |
| `hades` | Hades | black stone, embers and violet shade |
| `athena` | Athena | olive leaves, silver and owl grey |
| `apollo` | Apollo | warm white and burnished gold (light theme) |
| `artemis` | Artemis | moonlight silver on night blue |
| `ares` | Ares | blood red and battle bronze |
| `aphrodite` | Aphrodite | rose and pearl |
| `hermes` | Hermes | open sky and quick silver |
| `hephaestus` | Hephaestus | hot iron and furnace orange |
| `demeter` | Demeter | green fields and ripe wheat |
| `dionysus` | Dionysus | deep wine and ripe grapes |
| `hestia` | Hestia | amber firelight on warm wood |

Every built-in theme keeps text, muted text, the accents and the danger colour at a contrast of at least 4.5:1
(WCAG AA) on its background and surfaces; `tests/themes` checks this.

The boot screen (Plymouth) and the boot menu (Limine) stay gold in every theme: they run before anyone logs in.

## Switching

- **Settings → Appearance → Theme**: a card per theme, drawn in its own colours. A click uses it at once.
- **Super+Ctrl+Shift+Space**: the theme picker, anywhere. Arrows move, Enter (or a click) uses the theme while the
  picker stays open, Esc closes. The shortcut can be moved in Settings → Keyboard (`keys.themes`).
- **The command line**: `olymparch-theme set hades`, or `olymparch-settings set appearance.theme hades`.

The choice is kept in `~/.config/olymparch/settings.json` (`appearance.theme`). Switching applies live: the shell
and its windows recolour immediately, Hyprland's borders change through `hyprctl`, and every new foot terminal opens
in the new colours (terminals that are already open keep theirs). The lock screen uses the theme the next time it
locks.

## Backgrounds

Every theme has its backgrounds, and you pick one per theme. The first is always the torch-lit temple in the
theme's colours; the second is the god's own illustration, and after them come pictures of your own. Each theme
remembers its choice. A new theme starts on the temple.

| Theme | 1 | 2 |
|---|---|---|
| Zeus | Temple | Storm over Olympus |
| Aphrodite | Temple | Born of the sea foam |
| Apollo | Temple | The sun chariot at dawn |
| Ares | Temple | Battlefield at sunset |
| Artemis | Temple | The hind by moonlight |
| Athena | Temple | The owl of Athens |
| Demeter | Temple | Harvest moon |
| Dionysus | Temple | Vineyard at dusk |
| Hades | Temple | Charon on the Styx |
| Hephaestus | Temple | The forge in the volcano |
| Hera | Temple | The queen's peacock |
| Hermes | Temple | The messenger's road |
| Hestia | Temple | The hearth |
| Poseidon | Temple | The sea in storm |

The illustrations are still pictures, painted for a desktop: the light and the subject sit low or to the side, and
the strip under the bar and the top-right corner (where notifications appear) are kept quiet. Apollo's is light, like
his theme.

The **Live wallpaper** setting (Torch, Calm, Off) applies to every background that moves (the temple): Calm plays at
half speed and Off shows the first frame as a still. Like the temple, a background stops moving while windows cover it.

Pick one:

- **Super+Ctrl+Space** opens the background picker: thumbnails of the theme's backgrounds along the bottom of the
  screen. ← and → show each one at once behind everything, Enter (or a second click) keeps it, and Esc goes back to
  the one you had. The shortcut can be moved in Settings → Keyboard (`keys.backgrounds`).
- **Settings → Appearance → Background** shows the same thumbnails; a click uses one.
- **The command line**:

  ```
  olymparch-theme background list            the theme in use (* = chosen); list THEME for another one, --json
  olymparch-theme background set 3           by its number in the list, or by its id (styx, mine:beach.jpg)
  olymparch-theme background next | prev
  olymparch-theme background current
  ```

  `olymparch-settings set appearance.background@hades styx` does the same for any theme.

The shell can open the picker from elsewhere (a menu entry such as *Style → Background*) with
`qs ipc -p /usr/share/olymparch/shell call backgrounds open`; `… backgrounds next` and `… prev` switch without it.

The choice is kept in `~/.config/olymparch/settings.json` as one key per theme, `appearance.background@<theme>`, the
same way per-monitor settings are kept (`display.scale@DP-1`). A background that is gone (a picture you deleted)
falls back to the temple.

### Your own pictures

Put pictures in

- `~/.config/olymparch/backgrounds/<theme>/` for one theme (`…/backgrounds/hades/`), or
- `~/.config/olymparch/backgrounds/all/` for every theme.

They show up in the picker and in Settings the next time you open them, after the theme's own backgrounds. A picture
fills the screen and is cropped to fit (it is smoothed; pixel-art frames are not). Your pictures are checked
before the shell reads them: only PNG, JPEG and WebP files whose first bytes match the format, at most 20 MiB each, at
most 64 per theme. The name must start with a letter or digit and may hold letters, digits, spaces and `_ . , ( ) + -`
(at most 100 bytes); hidden files, symlinks and anything else are skipped. Their id is `mine:<file>` or `all:<file>`.
A picture is still: the Live wallpaper setting does not apply to it.

## Commands

```
olymparch-theme list [--json]    every theme (* = in use); built-in ones and yours
olymparch-theme current          the theme in use
olymparch-theme set ID           use a theme
olymparch-theme apply            write the files for the theme in use again and apply them live
olymparch-theme validate DIR     check a theme folder without installing it
olymparch-theme install URL      install a community theme from GitHub
olymparch-theme remove ID        remove a theme you installed
olymparch-theme background …     the backgrounds of the theme in use (see Backgrounds)
```

## Your own themes

Themes in `~/.config/olymparch/themes/<id>/` are yours. They are listed next to the built-in ones, and one with the
same id as a built-in theme replaces it (remove yours to get the built-in one back). The built-in themes live in
`/usr/share/olymparch/themes/`; copy one as a starting point:

```
cp -r /usr/share/olymparch/themes/hades ~/.config/olymparch/themes/my-hades
# edit ~/.config/olymparch/themes/my-hades/theme.json: set "id" to "my-hades", change the colours
olymparch-theme validate ~/.config/olymparch/themes/my-hades
olymparch-theme set my-hades
```

After editing the theme in use, run `olymparch-theme apply` to see the change.

## Community themes

```
olymparch-theme install https://github.com/OWNER/REPO
```

The repository must have `theme.json` at the top, and may have a `wallpaper/` and a `backgrounds/` folder. Only
`https://github.com/OWNER/REPO` and `https://github.com/OWNER/REPO.git` are accepted.

A theme is data, never code. The install makes a shallow clone over HTTPS only (no submodules, no hooks, no LFS,
symlinks are not checked out), checks `theme.json` strictly, writes it again from the checked values, copies only
frames that really are PNG files (regular files, at most 8 MiB each, at most 48 per size) for the wallpaper and for
each background `theme.json` names, and pictures in `backgrounds/` that pass the same checks as your own (at most 32),
and throws the clone away. Nothing from the repository is run, and no symlink in it is followed. A theme that fails a check is not
installed; `olymparch-theme validate` shows why.

## Format

A theme is a folder named after its id:

```
<id>/
  theme.json
  wallpaper/            optional: the first background (without it, Zeus' golden temple)
    1080/frame-00.png … frame-47.png
    1440/frame-00.png … frame-47.png
  backgrounds/          optional
    <scene>/            a background named in theme.json: frames like wallpaper/ (one frame is a still)
      1080/frame-00.png …
      1440/frame-00.png …
    lighthouse.jpg      pictures (PNG, JPEG, WebP): listed after the scenes, as pack:<file>
```

### theme.json

```json
{
  "id": "hades",
  "name": { "en": "Hades", "nb": "Hades" },
  "god": "Hades",
  "description": {
    "en": "The underworld: black stone, embers and violet shade.",
    "nb": "Underverdenen: svart stein, glør og fiolett skygge."
  },
  "light": false,
  "glyph": "f068c",
  "palette": {
    "bg": "#070507",
    "surface": "#130c14",
    "raised": "#1b111d",
    "line": "#3d2850",
    "text": "#ede2e8",
    "muted": "#a995b4",
    "accent": "#ec6a3f",
    "accentHi": "#ffa463",
    "danger": "#ff4f7a"
  },
  "terminal": ["#130c14", "#f0586c", "#a8bb83", "#d89e3b", "#8b9abe", "#b985ba", "#82a8ad", "#ede2e8",
               "#3d2850", "#f86c81", "#becb99", "#f3c359", "#a8b1cd", "#cea0ca", "#a0bcbe", "#ffffff"],
  "author": "you",
  "version": "1.0"
}
```

| Field | Required | Rules |
|---|---|---|
| `id` | yes | `^[a-z0-9-]{1,32}$`; must match the folder's name |
| `name` | yes | `{ "en": …, "nb": … }`; `en` required, `nb` optional; one line, at most 40 bytes each |
| `description` | yes | `{ "en": …, "nb": … }`; `en` required; one line, at most 200 bytes each |
| `god` | yes | one line, at most 40 bytes |
| `light` | no | `true` for a light theme (dark text on a light background); default `false` |
| `glyph` | no | the god's sign in the bar and picker: a Nerd Font code point in hex (private use area), e.g. `f0e7` (a bolt) |
| `palette` | yes | exactly the nine colours below, each `#RRGGBB` |
| `terminal` | yes | 16 colours, `#RRGGBB`: ANSI 0–7, then the bright 8–15 |
| `backgrounds` | no | the theme's scenes in order, at most 16: `[{ "id": "styx", "name": { "en": "Charon on the Styx", "nb": "Kharon på Styx" } }]`; `id` like a theme id but not `temple`, unique; `name` like `name`. A scene without frames in `backgrounds/<id>/1080/` is left out |
| `author`, `version` | no | one line of text; `version` like `1.0` |

No other fields are allowed, there are no numbers or `null`s, and the file is at most 64 KiB.

### The palette

| Colour | Used for |
|---|---|
| `bg` | the bar, panels' outer background, the terminal background, the wallpaper |
| `surface` | menus, notifications, the OSD, the Settings sidebar |
| `raised` | the selected row, a hovered item, an open dropdown |
| `line` | borders and dividers; the border of unfocused windows |
| `text` | normal text |
| `muted` | secondary text: descriptions, hints, inactive workspaces |
| `accent` | headings, marks, the focused window's border, filled buttons, the temple and its glow |
| `accentHi` | emphasis: the focused workspace, the item under the keyboard; the temple's highlights |
| `danger` | errors, critical notifications, a microphone in use, a wrong password |

`text` on `bg` and on `surface` must have a contrast of at least 4.5:1, or the theme is refused. `olymparch-theme
validate` also warns when `muted`, `accent`, `accentHi` or `danger` fall below 4.5:1 on what they are drawn on; the
built-in themes keep all of them at 4.5:1 or more. Text on a filled accent button is drawn in `bg`.

With Settings → Accessibility → High contrast, text becomes pure white (pure black in a light theme), and muted text
and lines move toward it.

### The wallpaper

Without a `wallpaper/` folder, a theme uses Zeus' golden temple. With one, the shell plays `frame-00.png`,
`frame-01.png` … in order (up to 48 frames, 8 per second, 4 with the Calm wallpaper setting; one frame is a still
picture) and the lock screen shows `frame-00.png`. `1080/` is used on screens up to 1300 pixels high, `1440/` on
taller ones (`1080/` if there is no `1440/`). The frames are scaled to fill the screen without smoothing, so pixel
art stays sharp.

The built-in themes get their frames from `art/torch.py`, the same temple and flickering torch in the theme's
colours (the temple, its glow and the sparks take the accent):

```
python art/torch.py OUT/1080 1920 1080 48 default/themes/hades/theme.json
```

`dev/build-iso` does this for every built-in theme.

The illustrations are drawn by hand as SVG, one per god: `art/illustrations/<id>.svg` (2560×1440, in the theme's
palette; what matters stays inside x 140–2420 so a 16:10 screen crops nothing important). Each is self-contained:
shapes, gradients and a few filters (noise for cloud edges, rock and grain), no pictures, text, fonts or links out
(`tests/themes` checks this). `dev/build-iso` draws each with `rsvg-convert` (librsvg) at 1920×1080 and 2560×1440 as
the theme's second background, a single frame:

```
python art/illustrations/render.py art/illustrations/hades.svg OUT/1080 1920 1080
```

(kept in `build/illustrations/` until the SVG changes). A background with one frame is a still, and the shell smooths
it when the screen is not exactly that size; the temple's frames are never smoothed.

All backgrounds together must stay under 120 MB on the ISO: the 14 temples take about 37 MB, the 14 illustrations at
most 80 MB (today about 63 MB, 1080 and 1440 together). Nothing is generated by AI or downloaded: the temples are
made by code from the palette, the illustrations drawn by hand in SVG, all under the repo's MIT licence.

## What is written where

`olymparch-theme apply` (run by Settings, by `set`, and at every login) checks the theme in use and writes:

| File | Read by |
|---|---|
| `~/.config/olymparch/theme/theme.json` | the shell and the lock screen (only this checked copy, never the theme itself) |
| `~/.config/olymparch/theme/hypr.lua` | Hyprland (`olymparch.lua` loads it; Settings' `hypr.lua` and your own lines still win) |
| `~/.config/olymparch/theme/foot.ini` | foot (`/etc/xdg/foot/foot.ini` includes it) |

These files are overwritten on every switch; change the theme instead. If the theme in use is missing or broken,
Zeus is used.
