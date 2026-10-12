// Super+Space: search and start apps. Esc or a click outside closes it.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: launcher
    required property var theme
    property bool open: false
    // Helper entries that come with dependencies and only clutter the menu
    readonly property var hidden: ["avahi-discover", "bssh", "bvnc", "footclient", "foot-server", "qv4l2", "qvidcap", "lstopo"]

    GlobalShortcut {
        appid: "olymparch"
        name: "launcher"
        description: "Open the Olymparch menu"
        onPressed: launcher.open = !launcher.open
    }

    PanelWindow {
        visible: launcher.open
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-launcher"
        WlrLayershell.keyboardFocus: launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: launcher.open = false }

        Rectangle {
            id: panel
            width: 520
            height: Math.min(460, 64 + list.contentHeight)
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.22
            color: launcher.theme.surface
            border.color: launcher.theme.line
            // gold corner marks, like the focused popups
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: launcher.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: launcher.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: launcher.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: launcher.theme.gold }
            MouseArea { anchors.fill: parent }   // clicks inside don't close it

            TextInput {
                id: search
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                height: 28
                font { family: launcher.theme.mono; pixelSize: launcher.theme.px(15) }
                color: launcher.theme.text
                verticalAlignment: TextInput.AlignVCenter
                focus: launcher.open
                onTextChanged: list.currentIndex = 0
                Keys.onEscapePressed: launcher.open = false
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onReturnPressed: list.launch(list.currentIndex)
                Text {
                    visible: !search.text
                    text: I18n.t("launcher.search", "Search apps …")
                    font: search.font
                    color: launcher.theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; top: search.bottom; topMargin: 8 } height: 1; color: launcher.theme.line }

            ListView {
                id: list
                anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: parent.bottom; topMargin: 12; margins: 6 }
                clip: true
                model: DesktopEntries.applications.values
                    .filter(e => !e.noDisplay && !launcher.hidden.includes(e.id) && e.name.toLowerCase().includes(search.text.toLowerCase()))
                    .sort((a, b) => a.name.localeCompare(b.name))
                function launch(i) {
                    const e = model[i];
                    if (!e) return;
                    e.execute();
                    launcher.open = false;
                }
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 30
                    color: ListView.isCurrentItem ? launcher.theme.raised : "transparent"
                    Rectangle { visible: parent.ListView.isCurrentItem; width: 2; height: parent.height; color: launcher.theme.gold }
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: parent.modelData.name
                        font { family: launcher.theme.mono; pixelSize: launcher.theme.px(14) }
                        color: parent.ListView.isCurrentItem ? launcher.theme.goldHi : launcher.theme.text
                    }
                    MouseArea { anchors.fill: parent; onClicked: list.launch(parent.index) }
                }
            }
        }
    }
    onOpenChanged: if (open) search.text = ""
}
