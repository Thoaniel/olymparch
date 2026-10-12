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
        resize_on_border = false,
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
shortcut("keys.lock", mod .. " + L", nil, function(k) hl.bind(k, hl.dsp.exec_cmd("olymparch-lock")) end)
shortcut("keys.close", mod .. " + Q", nil, function(k) hl.bind(k, hl.dsp.window.close()) end)
shortcut("keys.float", mod .. " + V", nil, function(k) hl.bind(k, hl.dsp.window.float({ action = "toggle" })) end)
shortcut("keys.exit", mod .. " + SHIFT + M", nil, function(k) hl.bind(k, hl.dsp.exit()) end)
shortcut("keys.add_game", mod .. " + SHIFT + G", nil, function(k) hl.bind(k, hl.dsp.exec_cmd("olymparch-game add-focused")) end)   -- this window is a game
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
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- Settings is a window of the shell; it floats in the middle instead of taking a tile
hl.window_rule({ name = "olymparch-settings", match = { title = "^Olymparch Settings$" }, float = true, center = true, size = "monitor_w*0.82 monitor_h*0.86" })

-- The shell (bar, wallpaper) starts with the session
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/olymparch/launch-shell")
    hl.exec_cmd("udiskie --automount --notify --no-tray")   -- USB disks: mounted, with Open / Eject in the notification
    hl.exec_cmd("olymparch-welcome")   -- first-login hints (e.g. set up Zeus)
    hl.exec_cmd("sh -c 'f=$HOME/.config/hypr/hypridle.conf; [ -f \"$f\" ] || f=/usr/share/olymparch/idle/hypridle.conf; exec hypridle -c \"$f\"'")
end)

-- Games need no launch options: every new window is traced back to its process, and a game gets gamemode
-- (and with it spillmodus: bar hidden, do not disturb). See olymparch-game-hook.
hl.on("window.open", function(w)
    hl.exec_cmd("olymparch-game-hook window " .. tostring(w.address) .. " " .. tostring(w.pid or 0))
end)
