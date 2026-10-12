// The notification server: the shell is the only one (no mako, dunst or swaync). Toasts top right under the
// bar, at most 3 at a time, 6 s each (critical ones stay until dismissed); all of it is in Settings → Notifications.
// Do not disturb hides everything but critical toasts.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: notes
    required property var theme
    readonly property bool dnd: Settings.get("notifications.dnd") === true
    readonly property string position: Settings.get("notifications.position")
    readonly property bool top: position.startsWith("top")
    readonly property bool left: position.endsWith("left")
    readonly property var shown: server.trackedNotifications.values
        .filter(n => !dnd || n.urgency === NotificationUrgency.Critical)
        .slice(-Settings.get("notifications.max_visible")).reverse()

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        onNotification: n => {
            n.tracked = true;
            if (n.urgency !== NotificationUrgency.Critical) {
                const t = Qt.createQmlObject(`import QtQuick; Timer { interval: ${Settings.get("notifications.duration") * 1000}; running: true }`, notes);
                t.triggered.connect(() => { if (n) n.expire(); t.destroy(); });
            }
        }
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: notes.shown.length > 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-notifications"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: notes.top; bottom: !notes.top; left: notes.left; right: !notes.left }
        margins { top: 42; bottom: 10; left: 10; right: 10 }
        implicitWidth: 360
        implicitHeight: column.implicitHeight
        color: "transparent"

        Column {
            id: column
            width: parent.width
            spacing: 8
            Repeater {
                model: notes.shown
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    width: column.width
                    height: body.implicitHeight + 24
                    color: notes.theme.surface
                    border.color: critical ? notes.theme.red : notes.theme.line
                    Rectangle { width: 3; height: parent.height; color: parent.critical ? notes.theme.red : notes.theme.gold }
                    Column {
                        id: body
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 16 }
                        spacing: 3
                        Text {
                            text: (parent.parent.modelData.appName || "System").toUpperCase()
                            font { family: notes.theme.mono; pixelSize: 11; letterSpacing: 1.5; bold: true }
                            color: parent.parent.critical ? notes.theme.red : notes.theme.gold
                        }
                        Text {
                            width: parent.width
                            text: parent.parent.modelData.summary
                            font { family: notes.theme.mono; pixelSize: 14; bold: true }
                            color: notes.theme.text
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: parent.parent.modelData.body
                            font { family: notes.theme.mono; pixelSize: 13 }
                            color: notes.theme.muted
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: parent.modelData.dismiss() }
                }
            }
        }
    }
}
