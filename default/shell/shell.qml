//@ pragma ShellId olymparch
// Olymparch shell: the animated temple wallpaper, the bar (BarStatus: media, mic/camera, network, volume, battery,
// do not disturb, clock), the menu (Super+Space), notifications, the volume OSD and Settings (Super+comma).
// What can be changed is read from Settings (settings.json) and follows it live.
// Spillmodus (GameMode.qml) hides the bar and turns on do not disturb while a game runs.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    readonly property color bg: "#0a0a0e"
    readonly property color line: "#3a3644"
    readonly property color text: "#e8e6df"
    readonly property color muted: "#9a96a3"
    readonly property color gold: "#d4a73a"
    readonly property color goldHi: "#f4d35e"
    readonly property color surface: "#15151c"
    readonly property color raised: "#1c1c25"
    readonly property color red: "#e0605e"
    readonly property string mono: "JetBrains Mono"
    readonly property string art: "/usr/share/olymparch/wallpaper"
    readonly property int frames: 48
    // Do not disturb: the setting (kept; the bell in the bar flips it), «olymparch dnd» for now, or a running game
    readonly property bool dndSetting: Settings.get("notifications.dnd") === true
    function toggleDnd() {
        Quickshell.execDetached(["olymparch-settings", "set", "notifications.dnd", dndSetting ? "off" : "on"]);
    }

    // One frame counter for every monitor. Torch 8 fps, Calm 4 fps, Off (or reduced motion) stays on frame 00.
    // It stops while every workspace in view has windows.
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
        running: root.templeVisible && root.wallpaper !== "off"
        onTriggered: root.frame = (root.frame + 1) % root.frames
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "olymparch-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#08080c"

            Image {
                anchors.fill: parent
                readonly property string set: parent.height >= 1300 ? "1440" : "1080"
                source: `file://${root.art}/${set}/frame-${String(root.frame).padStart(2, "0")}.png`
                fillMode: Image.PreserveAspectCrop
                smooth: false
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
                            font { family: root.mono; pixelSize: 13; bold: parent.modelData.focused }
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
                    text: "\uf0e7"
                    font { family: "Symbols Nerd Font Mono"; pixelSize: 15 }
                    color: root.gold
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    visible: barStatus.x > (parent.parent.width + wordmarkFull.advanceWidth) / 2 + 24
                    text: "OLYMPARCH"
                    font { family: root.mono; pixelSize: 13; bold: true; letterSpacing: 2 }
                    color: root.gold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            TextMetrics { id: wordmarkFull; font { family: root.mono; pixelSize: 13; bold: true; letterSpacing: 2 } text: "OLYMPARCH  " }

            BarStatus {
                id: barStatus
                theme: root
                clockFormat: (Settings.get("appearance.clock_format") === "12h" ? "ddd d%1 MMM  h:mm AP" : "ddd d%1 MMM  HH:mm")
                    .arg(Qt.locale().name.startsWith("nb") || Qt.locale().name.startsWith("nn") ? "." : "")
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            }
        }
    }

    GameMode { id: gameMode }
    Launcher { theme: root }
    Notifications { theme: root; dnd: gameMode.dnd || root.dndSetting }
    Power {}
    Osd { theme: root }
    SettingsWindow { theme: root }
}
