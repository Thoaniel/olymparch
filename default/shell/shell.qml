//@ pragma ShellId olymparch
// Olymparch shell: the animated temple wallpaper, the bar, the menu (Super+Space), notifications and the volume OSD.
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

    // One frame counter for every monitor. 8 fps, and it stops while every workspace in view has windows.
    property int frame: 0
    readonly property bool templeVisible: {
        const ws = Hyprland.focusedWorkspace;
        return !ws || !ws.toplevels || ws.toplevels.values.length === 0;
    }
    Timer {
        interval: 125
        repeat: true
        running: root.templeVisible
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

            Text {
                anchors.centerIn: parent
                text: "\uf0e7  OLYMPARCH"
                font { family: root.mono; pixelSize: 13; bold: true; letterSpacing: 2 }
                color: root.gold
            }

            SystemClock { id: clock; precision: SystemClock.Minutes }
            Text {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: Qt.formatDateTime(clock.date, "ddd d. MMM  HH:mm")
                font { family: root.mono; pixelSize: 13 }
                color: root.text
            }
        }
    }

    Launcher { theme: root }
    Notifications { theme: root }
    Osd { theme: root }
}
