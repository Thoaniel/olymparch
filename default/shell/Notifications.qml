// The notification server: the shell is the only one (no mako, dunst or swaync). Toasts top right under the
// bar, at most 3 at a time, 6 s each (critical ones stay until dismissed).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: notes
    required property var theme

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        onNotification: n => {
            n.tracked = true;
            // offers with buttons (e.g. «Install driver») stay until answered, like critical ones
            if (n.urgency !== NotificationUrgency.Critical && n.actions.length === 0) {
                const t = Qt.createQmlObject("import QtQuick; Timer { interval: 6000; running: true }", notes);
                t.triggered.connect(() => { if (n) n.expire(); t.destroy(); });
            }
        }
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: server.trackedNotifications.values.length > 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-notifications"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins { top: 42; right: 10 }
        implicitWidth: 360
        implicitHeight: column.implicitHeight
        color: "transparent"

        Column {
            id: column
            width: parent.width
            spacing: 8
            Repeater {
                model: server.trackedNotifications.values.slice(-3).reverse()
                delegate: Rectangle {
                    id: card
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
                        // Action buttons (notify-send -A): the first is the primary one, in gold
                        Row {
                            visible: card.modelData.actions.length > 0
                            topPadding: 6
                            spacing: 8
                            Repeater {
                                model: card.modelData.actions
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: label.implicitWidth + 24
                                    height: 28
                                    z: 2
                                    color: index === 0 ? notes.theme.gold : notes.theme.surface
                                    border.color: index === 0 ? notes.theme.gold : notes.theme.line
                                    Text {
                                        id: label
                                        anchors.centerIn: parent
                                        text: parent.modelData.text
                                        font { family: notes.theme.mono; pixelSize: 12; bold: true }
                                        color: parent.index === 0 ? "#0a0a0e" : notes.theme.text
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: parent.modelData.invoke() }
                                }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; z: -1; onClicked: parent.modelData.dismiss() }
                }
            }
        }
    }
}
