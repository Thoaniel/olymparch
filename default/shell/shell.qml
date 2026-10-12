//@ pragma ShellId olymparch
// Olymparch shell: the animated temple wallpaper, the bar (BarStatus: media, mic/camera, network, volume, battery,
// do not disturb, clock), the menu (Super+Space), notifications, the volume OSD and Settings (Super+comma).
// What can be changed is read from Settings (settings.json) and follows it live.
// Spillmodus (GameMode.qml) hides the bar and turns on do not disturb while a game runs.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root
    // ── Theme: the colours, glyph and wallpaper of the active theme (Settings → Appearance → Theme, Super+Ctrl+Shift+Space,
    //    `olymparch-theme set ID`). olymparch-theme checks the theme and writes ~/.config/olymparch/theme/theme.json;
    //    this reads only that file, and Zeus' black and gold stand in for anything missing. See docs/themes.md.
    readonly property var themeData: {
        const t = themeFile.text();
        if (!t || !t.trim()) return {};
        try { return JSON.parse(t) || {}; } catch (e) { return {}; }
    }
    function themeColour(k, zeus) {
        const v = (themeData.palette || {})[k];
        return /^#[0-9a-fA-F]{6}$/.test(v || "") ? v : zeus;
    }
    function mix(a, b, t) { return Qt.tint(a, Qt.rgba(b.r, b.g, b.b, t)); }
    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/olymparch/theme/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    IpcHandler {   // olymparch-theme apply calls this, so the new colours show at once
        target: "theme"
        function reload(): void { themeFile.reload(); }
    }
    readonly property string themeId: /^[a-z0-9-]{1,32}$/.test(themeData.id || "") ? themeData.id : "zeus"
    readonly property bool light: themeData.light === true
    readonly property color bg: themeColour("bg", "#0a0a0e")
    readonly property bool highContrast: Settings.get("accessibility.high_contrast") === true   // Settings → Accessibility
    readonly property color line: highContrast ? mix(themeColour("line", "#3a3644"), text, 0.45) : themeColour("line", "#3a3644")
    readonly property color text: highContrast ? (light ? "#000000" : "#ffffff") : themeColour("text", "#e8e6df")
    readonly property color muted: highContrast ? mix(themeColour("muted", "#9a96a3"), text, 0.6) : themeColour("muted", "#9a96a3")
    readonly property color gold: themeColour("accent", "#d4a73a")        // the accent (gold in Zeus)
    readonly property color goldHi: themeColour("accentHi", "#f4d35e")    // the accent, emphasised
    readonly property color surface: themeColour("surface", "#15151c")
    readonly property color raised: themeColour("raised", "#1c1c25")
    readonly property color red: themeColour("danger", "#e0605e")
    readonly property color field: mix(bg, surface, 0.4)          // input boxes, switches, sliders
    readonly property color selected: mix(bg, gold, 0.1)          // a row that is waiting for you (recording a shortcut)
    readonly property color onAccent: bg                          // text on an accent-filled button
    readonly property color dim: mix(muted, bg, 0.15)             // the file/command hint under a setting
    readonly property color scrim: Qt.rgba(bg.r, bg.g, bg.b, 0.6) // behind a question in the middle of the screen
    readonly property color wallpaperBg: light ? bg : Qt.darker(bg, 1.25)
    readonly property string glyph: {   // the god's sign in the bar (a Nerd Font code point)
        const cp = parseInt(themeData.glyph || "f0e7", 16);
        return (cp >= 0xe000 && cp <= 0xf8ff) || (cp >= 0xf0000 && cp <= 0xffffd) ? String.fromCodePoint(cp) : "\uf0e7";
    }
    // ── Background: the theme's (theme.json names it: frames in a folder, or one picture of yours), or the one the
    //    background picker (Super+Ctrl+Space) is trying. Paths are only taken whole and absolute, never with «..».
    property var bgPreview: null   // an entry from `olymparch-theme background list --json` while the picker tries it
    readonly property var bgNow: bgPreview || themeData
    function safePath(p) { return typeof p === "string" && /^\/[^\0]*$/.test(p) && p.indexOf("..") < 0; }
    readonly property string art: safePath(bgNow.wallpaper || bgNow.dir) ? (bgNow.wallpaper || bgNow.dir) : "/usr/share/olymparch/wallpaper"
    readonly property string picture: safePath(bgNow.image) ? bgNow.image : ""
    readonly property int frames: picture ? 1 : Math.max(1, Math.min(48, bgNow.frames || 48))
    onFramesChanged: frame = 0
    onArtChanged: frame = 0
    readonly property bool has1440: !bgNow.sets || bgNow.sets.indexOf("1440") >= 0
    // ── end Theme
    // Settings → Accessibility → Text size: every font in the shell is theme.px(size)
    readonly property real fontScale: ({ "125": 1.25, "150": 1.5 })[Settings.get("accessibility.text_size")] || 1
    function px(n) { return Math.round(n * fontScale); }
    readonly property string mono: Settings.get("appearance.font") || "JetBrains Mono"   // Settings → Appearance
    // Do not disturb: the setting (kept; the bell in the bar flips it), «olymparch dnd» for now, or a running game
    readonly property bool dndSetting: Settings.get("notifications.dnd") === true
    function toggleDnd() {
        Quickshell.execDetached(["olymparch-settings", "set", "notifications.dnd", dndSetting ? "off" : "on"]);
    }

    // One frame counter for every monitor and every background. Torch 8 fps, Calm 4 fps, Off (or reduced motion)
    // stays on frame 00; a still background (one frame, or a picture) never ticks. It stops while every workspace in
    // view has windows.
    readonly property string wallpaper: Settings.get("accessibility.reduced_motion") === true ? "off" : Settings.get("appearance.wallpaper")
    onWallpaperChanged: if (wallpaper === "off") frame = 0
    property int frame: 0
    readonly property bool templeVisible: {
        const ws = Hyprland.focusedWorkspace;
        return !ws || !ws.toplevels || ws.toplevels.values.length === 0;
    }
    Timer {
        interval: root.wallpaper === "calm" ? 250 : 125
        repeat: true
        running: root.templeVisible && root.wallpaper !== "off" && root.frames > 1
        onTriggered: root.frame = (root.frame + 1) % root.frames
    }

    // The wallpaper and the bar per monitor. Rebuilt after the monitor layout changes (olymparch-settings calls
    // «screens»): a panel on an output that moved can otherwise stay blank.
    LazyLoader {
        id: panels
        active: true
        Scope {
            Variants {
                model: Quickshell.screens

                PanelWindow {
                    required property var modelData
                    screen: modelData
                    WlrLayershell.layer: WlrLayer.Background
                    WlrLayershell.namespace: "olymparch-wallpaper"
                    exclusionMode: ExclusionMode.Ignore
                    anchors { top: true; bottom: true; left: true; right: true }
                    color: root.wallpaperBg

                    Image {
                        anchors.fill: parent
                        readonly property string set: parent.height >= 1300 && root.has1440 ? "1440" : "1080"
                        // a picture of yours or a still illustration (one frame) fills the screen cropped and smoothed;
                        // pixel-art frames (the temple) stay sharp
                        source: root.picture ? "file://" + encodeURI(root.picture)
                                             : `file://${root.art}/${set}/frame-${String(root.frame).padStart(2, "0")}.png`
                        fillMode: Image.PreserveAspectCrop
                        smooth: root.picture !== "" || root.frames === 1
                        cache: true
                        asynchronous: false
                    }
                }
            }

            Variants {
                model: Quickshell.screens

                PanelWindow {
                    required property var modelData
                    screen: modelData
                    visible: Settings.get("appearance.bar") !== false && !gameMode.active
                    WlrLayershell.namespace: "olymparch-bar"
                    anchors { top: true; left: true; right: true }
                    implicitHeight: 34
                    color: root.bg

                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: root.line }

                    Row {
                        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Item {
                                required property HyprlandWorkspace modelData
                                width: 28; height: 32
                                visible: modelData.id > 0
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.id
                                    font { family: root.mono; pixelSize: root.px(13); bold: parent.modelData.focused }
                                    color: parent.modelData.focused ? root.goldHi : root.muted
                                }
                                Rectangle {
                                    visible: parent.modelData.focused
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: 2; color: root.gold
                                }
                                MouseArea { anchors.fill: parent; onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${parent.modelData.id} })`) }
                            }
                        }
                    }

                    // The wordmark gives way (only the bolt stays) when the right side grows into it on a narrow screen
                    Row {
                        id: wordmark
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            text: root.glyph
                            font { family: "Symbols Nerd Font Mono"; pixelSize: root.px(15) }
                            color: root.gold
                            anchors.verticalCenter: parent.verticalCenter
                            // ── the bolt opens the Olymparch menu (Menu.qml)
                            MouseArea { anchors { fill: parent; margins: -8 } cursorShape: Qt.PointingHandCursor; onClicked: olymparchMenu.toggle() }
                        }
                        Text {
                            visible: barStatus.x > (parent.parent.width + wordmarkFull.advanceWidth) / 2 + 24
                            text: "OLYMPARCH"
                            font { family: root.mono; pixelSize: root.px(13); bold: true; letterSpacing: 2 }
                            color: root.gold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    TextMetrics { id: wordmarkFull; font { family: root.mono; pixelSize: root.px(13); bold: true; letterSpacing: 2 } text: "OLYMPARCH  " }

                    BarStatus {
                        id: barStatus
                        theme: root
                        clockFormat: (Settings.get("appearance.clock_format") === "12h" ? "ddd d%1 MMM  h:mm AP" : "ddd d%1 MMM  HH:mm")
                            .arg(Qt.locale().name.startsWith("nb") || Qt.locale().name.startsWith("nn") ? "." : "")
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
    IpcHandler {
        target: "shell"
        function screens(): void { panels.active = false; Qt.callLater(() => panels.active = true); }
    }

    GameMode { id: gameMode }
    Launcher { id: launcher; theme: root }
    // ── the Olymparch menu (Super+Alt+Space, the bolt in the bar) and the list of shortcuts (Super+K)
    Menu { id: olymparchMenu; theme: root; launcher: launcher; cheatsheet: cheatsheet }
    Cheatsheet { id: cheatsheet; theme: root }
    PasswordPrompt { theme: root; what: olymparchMenu.authWhat }   // the polkit agent: password prompts (the menu's package helper asks)
    // ── (end of the menu block)
    // Settings → Notifications → in games: all (as usual), critical (only those), none (held back until it ends)
    readonly property string inGames: Settings.get("notifications.in_games")
    Notifications {
        theme: root
        dnd: (gameMode.active && root.inGames !== "all") || gameMode.manualDnd || root.dndSetting
        silent: gameMode.active && root.inGames === "none"
    }
    Power {}
    Media {}   // the media keys without playerctl (olymparch-media → qs ipc call media …)
    Osd { theme: root }
    SettingsWindow { theme: root }
    // ── everyday tools (olymparch-tool): clipboard history (Super+Ctrl+V) and emoji (Super+period)
    Clipboard { theme: root }
    Emoji { theme: root }
    ThemePicker { theme: root }   // Super+Ctrl+Shift+Space
    // ── AI agents (olymparch-mcp): the approval card for what an agent wants to change; none while a game runs
    McpApproval { theme: root; gameActive: gameMode.active }
    BackgroundPicker { theme: root }   // Super+Ctrl+Space
}
