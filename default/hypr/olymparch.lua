-- Olymparch default Hyprland config (0.56, Lua). Loaded from ~/.config/hypr/hyprland.lua; the user's own
-- files are loaded after this and win.

local gold, line = "rgb(d4a73a)", "rgb(3a3644)"

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-- Every monitor at its preferred mode; the monitor menu in Settings writes real layouts later.
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
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 2,
        focus_on_activate = false,
    },
})

hl.curve("olymp", { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "olymp", style = "popin 90%" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "olymp", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "olymp", style = "fade" })

-- Keys
local mod = "SUPER"
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("foot"))
hl.bind(mod .. " + SPACE", hl.dsp.global("olymparch:launcher"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exit())
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- The shell (bar, wallpaper) starts with the session
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/olymparch/launch-shell")
end)
