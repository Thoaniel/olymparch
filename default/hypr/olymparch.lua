-- Olymparch default Hyprland config (0.56, Lua). Loaded from ~/.config/hypr/hyprland.lua; then what Settings
-- wrote (~/.config/olymparch/monitors.lua and hypr.lua), then the user's own lines, which win. Every option a
-- user could want to change here has an entry in /usr/share/olymparch/settings/schema.json (tests/settings-coverage).

local gold, line = "rgb(d4a73a)", "rgb(3a3644)"

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-- Session variables the hardware rules ask for (olymparch-hw writes KEY=VALUE lines, e.g. for NVIDIA)
local hwenv = io.open("/etc/olymparch/hw/hypr-env")
if hwenv then
    for line in hwenv:lines() do
        local k, v = line:match("^([%w_]+)=(.*)$")
        if k then hl.env(k, v) end
    end
    hwenv:close()
end

-- Every monitor at its preferred mode; Settings → Displays writes per-monitor rules to monitors.lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = { active_border = gold, inactive_border = line },
        resize_on_border = true,   -- a window's edge can be dragged to resize it, as people expect
        allow_tearing = true,
        layout = "dwindle",
    },
    dwindle = { preserve_split = true },
    -- No blur, shadows or rounding: every pixel stays crisp, and nothing costs GPU time while gaming
    decoration = {
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    animations = { enabled = true },
    input = {
        kb_layout = os.getenv("OLYMPARCH_KB_LAYOUT") or "us",
        follow_mouse = 1,
        sensitivity = 0,
        accel_profile = "flat",
        numlock_by_default = true,
    },
    misc = {
        force_default_wallpaper = 0,
        background_color = "rgb(08080c)",   -- same as the boot screen, so the hand-off never flashes
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 2,
        focus_on_activate = false,
        allow_session_lock_restore = true,   -- a crashed lock screen can be restarted without unlocking
    },
})

hl.curve("olymp", { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "olymp", style = "popin 90%" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "olymp", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "olymp", style = "fade" })

-- Keys. Every shortcut has a name (keys.* in Settings → Keyboard). hypr.lua, written by Settings, calls
-- olymparch_keys({ [name] = combo, … }) to move them: all their defaults are unbound first, then the new combos
-- bound ("" = no shortcut), so two shortcuts can swap. For one with `each` (1…0, arrows, mouse buttons) the
-- combo is just the modifiers.
local mod = "SUPER"
local shortcuts = {}
local function shortcut(name, combo, each, bind)
    shortcuts[name] = { combo = combo, each = each, bind = bind }
    bind(combo)
end
function olymparch_keys(moved)
    for name in pairs(moved) do
        local k = shortcuts[name]
        if k and k.each then for _, s in ipairs(k.each) do hl.unbind(k.combo .. " + " .. s) end
        elseif k then hl.unbind(k.combo) end
    end
    for name, combo in pairs(moved) do
        if shortcuts[name] and type(combo) == "string" and combo ~= "" then shortcuts[name].bind(combo) end
    end
end
-- While Settings records a new shortcut, Hyprland's own are paused (this submap has no others), so the window
-- gets every key. Settings leaves it again by itself; Super+Escape does too.
hl.define_submap("olymparch-record", function() hl.bind("SUPER + ESCAPE", hl.dsp.submap("reset")) end)
local digits, arrows = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }, { "left", "right", "up", "down" }
shortcut("keys.terminal", mod .. " + RETURN", nil, function(k) hl.bind(k, hl.dsp.exec_cmd("sh -c 'exec \"${OLYMPARCH_TERMINAL:-foot}\"'")) end)
shortcut("keys.menu", mod .. " + SPACE", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:launcher")) end)
shortcut("keys.settings", mod .. " + COMMA", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:settings")) end)
shortcut("keys.themes", mod .. " + CTRL + SHIFT + SPACE", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:themes")) end)   -- the theme picker
shortcut("keys.backgrounds", mod .. " + CTRL + SPACE", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:backgrounds")) end)   -- the background picker
shortcut("keys.lock", mod .. " + L", nil, function(k) hl.bind(k, hl.dsp.exec_cmd("olymparch-lock")) end)
shortcut("keys.close", mod .. " + Q", nil, function(k) hl.bind(k, hl.dsp.window.close()) end)
shortcut("keys.float", mod .. " + V", nil, function(k) hl.bind(k, hl.dsp.window.float({ action = "toggle" })) end)
shortcut("keys.exit", mod .. " + SHIFT + M", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:logout")) end)   -- asks first (Menu.qml)
shortcut("keys.fullscreen", mod .. " + F", nil, function(k) hl.bind(k, hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })) end)
shortcut("keys.maximize", mod .. " + M", nil, function(k) hl.bind(k, hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })) end)
shortcut("keys.add_game", mod .. " + SHIFT + G", nil, function(k) hl.bind(k, hl.dsp.exec_cmd("olymparch-game add-focused")) end)   -- this window is a game
shortcut("zeus.hotkey", mod .. " + Z", nil, function(k) hl.bind(k, hl.dsp.exec_cmd("olymparch-settings zeus-open")) end)   -- Zeus, when installed
shortcut("keys.agents", mod .. " + A", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:panel-agents")) end)   -- the Agents panel
-- The Olymparch menu (Menu.qml: everything in one list) and the list of shortcuts (Cheatsheet.qml)
shortcut("keys.olymparch_menu", mod .. " + ALT + SPACE", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:menu")) end)
shortcut("keys.cheatsheet", mod .. " + K", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:cheatsheet")) end)
shortcut("keys.workspace", mod, digits, function(m)
    for i = 1, 10 do hl.bind(m .. " + " .. digits[i], hl.dsp.focus({ workspace = i })) end
end)
shortcut("keys.move_to_workspace", mod .. " + SHIFT", digits, function(m)
    for i = 1, 10 do hl.bind(m .. " + " .. digits[i], hl.dsp.window.move({ workspace = i })) end
end)
shortcut("keys.focus", mod, arrows, function(m)
    for _, d in ipairs(arrows) do hl.bind(m .. " + " .. d, hl.dsp.focus({ direction = d })) end
end)
shortcut("keys.mouse", mod, { "mouse:272", "mouse:273" }, function(m)
    hl.bind(m .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(m .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
end)
-- ── Everyday tools (olymparch-tool): screenshots, screen recording, colour picker, text from the screen (OCR),
--    clipboard history and emoji
local function tool(args) return function(k) hl.bind(k, hl.dsp.exec_cmd("olymparch-tool " .. args)) end end
shortcut("keys.screenshot", "PRINT", nil, tool("screenshot region"))
shortcut("keys.screenshot_screen", "SHIFT + PRINT", nil, tool("screenshot screen"))
shortcut("keys.screenshot_window", mod .. " + PRINT", nil, tool("screenshot window"))
shortcut("keys.screenshot_alt", mod .. " + SHIFT + S", nil, tool("screenshot region"))   -- for keyboards without Print (and Windows habits)
shortcut("keys.record", mod .. " + SHIFT + R", nil, tool("record region"))
shortcut("keys.colorpicker", mod .. " + SHIFT + C", nil, tool("colorpicker"))
shortcut("keys.ocr", mod .. " + SHIFT + T", nil, tool("ocr"))
shortcut("keys.clipboard", mod .. " + CTRL + V", nil, tool("clipboard"))
shortcut("keys.emoji", mod .. " + PERIOD", nil, tool("emoji"))
-- the newest notification without the mouse: its gold button (Edit, Play, OK …), or away
shortcut("keys.notification_action", mod .. " + SHIFT + RETURN", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:notification-action")) end)
shortcut("keys.notification_dismiss", mod .. " + SHIFT + ESCAPE", nil, function(k) hl.bind(k, hl.dsp.global("olymparch:notification-dismiss")) end)
-- the screenshot editor floats in the middle
hl.window_rule({ name = "olymparch-satty", match = { class = "^com\\.gabm\\.satty$" }, float = true, center = true, size = "monitor_w*0.72 monitor_h*0.78" })
-- ── end everyday tools
-- Media keys (keys.media): volume through wpctl, play/pause/next/previous through olymparch-media (playerctl, or the
-- shell's player). hypr.lua calls olymparch_media_keys(false) when Settings turns them off, so apps get the keys.
local media_keys = {
    { "XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", { locked = true, repeating = true } },
    { "XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", { locked = true, repeating = true } },
    { "XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", { locked = true } },
    { "XF86AudioPlay", "olymparch-media play-pause", { locked = true } },
    { "XF86AudioPause", "olymparch-media play-pause", { locked = true } },
    { "XF86AudioNext", "olymparch-media next", { locked = true } },
    { "XF86AudioPrev", "olymparch-media previous", { locked = true } },
    { "XF86AudioStop", "olymparch-media stop", { locked = true } },
}
for _, k in ipairs(media_keys) do hl.bind(k[1], hl.dsp.exec_cmd(k[2]), k[3]) end
function olymparch_media_keys(on)
    if on == false then for _, k in ipairs(media_keys) do hl.unbind(k[1]) end end
end

-- Settings is a window of the shell; it floats in the middle instead of taking a tile
hl.window_rule({ name = "olymparch-settings", match = { title = "^Olymparch Settings$" }, float = true, center = true, size = "monitor_w*0.82 monitor_h*0.86" })
-- Web apps (olymparch-webapp): tiled like any app, but a site may not maximize its window on its own, and a
-- video in full screen keeps the screen awake
-- (class webapp-ID on X11; on Wayland Chromium calls the window chrome-SITE-webapp-ID, after its profile folder)
hl.window_rule({ name = "olymparch-webapps", match = { class = "^(webapp-|chrome-.*-webapp-)[a-z0-9-]+$" }, suppress_event = "maximize", idle_inhibit = "fullscreen" })

-- The shell (bar, wallpaper) starts with the session
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/olymparch/launch-shell")
    -- USB disks: mounted, with Open / Eject in the notification (Settings → Disks → Open USB disks automatically)
    hl.exec_cmd("sh -c '[ \"$(olymparch-settings get disks.usb_automount 2>/dev/null)\" = false ] && exec udiskie --no-automount --notify --no-tray; exec udiskie --automount --notify --no-tray'")
    hl.exec_cmd("olymparch-welcome")   -- first-login hints (e.g. set up Zeus)
    hl.exec_cmd("sh -c 'f=$HOME/.config/hypr/hypridle.conf; [ -f \"$f\" ] || f=/usr/share/olymparch/idle/hypridle.conf; exec hypridle -c \"$f\"'")
    -- Night light (Settings → Displays): hyprsunset with ~/.config/hypr/hyprsunset.conf (warmer 20:00–07:00)
    hl.exec_cmd("sh -c '[ \"$(olymparch-settings get display.night_light 2>/dev/null)\" = true ] && command -v hyprsunset >/dev/null && exec hyprsunset'")
end)

-- Settings → Accessibility → Screen reader: Orca starts with the session while it is on (and installed)
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c '[ \"$(olymparch-settings get accessibility.screen_reader 2>/dev/null)\" = true ] && command -v orca >/dev/null && exec orca'")
end)

-- Clipboard history (Settings → Privacy): cliphist keeps text and images; the watcher exits at once while it is off
hl.on("hyprland.start", function() hl.exec_cmd("olymparch-tool clip-watch") end)

-- Games need no launch options: every new window is traced back to its process, and a game gets gamemode
-- (and with it spillmodus: bar hidden, do not disturb). See olymparch-game-hook.
hl.on("window.open", function(w)
    hl.exec_cmd("olymparch-game-hook window " .. tostring(w.address) .. " " .. tostring(w.pid or 0))
end)

-- Every monitor combination remembers its layout: plugging monitors in or out applies the layout saved for exactly
-- that set (by make/model/serial, not port), or offers to arrange a new one. Settings → Displays saves it.
for _, event in ipairs({ "hyprland.start", "monitor.added", "monitor.removed" }) do
    hl.on(event, function() hl.exec_cmd("olymparch-settings monitors-changed") end)
end

-- ── Theme (olymparch-theme, Settings → Appearance → Theme): the active theme's border and background colours are in
-- ~/.config/olymparch/theme/hypr.lua. Loaded here, so Settings' hypr.lua and your own lines still win. At the start of
-- the session olymparch-theme writes it (and the shell's, the lock screen's and foot's copies) again, so a new or
-- updated theme is always in place; its colours are applied live with hyprctl.
do
    local f = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") or "") .. "/.config") .. "/olymparch/theme/hypr.lua"
    local ok, err = pcall(dofile, f)
    if not ok and not tostring(err):find("No such file") then print("olymparch theme: " .. tostring(err)) end
end
hl.on("hyprland.start", function() hl.exec_cmd("olymparch-theme apply --quiet") end)
-- ── end Theme
