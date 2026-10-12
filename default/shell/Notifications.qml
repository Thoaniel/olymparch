// The notification server: the shell is the only one (no mako, dunst or swaync). Toasts top right under the
// bar, at most as many as Settings says, for as long as it says (ones with buttons and critical ones stay until
// answered or dismissed); all of it is in Settings → Notifications. Do not disturb hides everything but critical.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: notes
    required property var theme
    property bool dnd: false   // shell.qml: Settings → do not disturb (also the bell in the bar), or spillmodus
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
            const critical = n.urgency === NotificationUrgency.Critical;
            if (notes.dnd && !critical) return;   // not tracked: dropped quietly
            n.tracked = true;
            // offers with buttons («Install driver», «Undo» …) stay until answered, like critical ones
            if (!critical && n.actions.length === 0) {
                const t = Qt.createQmlObject(`import QtQuick; Timer { interval: ${Settings.get("notifications.duration") * 1000}; running: true }`, notes);
                // the toast may be gone already (dismissed)
                t.triggered.connect(() => { try { if (n) n.expire(); } catch (e) {} t.destroy(); });
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
        margins { top: 42; bottom: 10; left: 10; right: 12 }
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
                        z: 1   // above the dismiss area, so the buttons get their clicks
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 16 }
                        spacing: 3
                        Text {   // the sender; left out for plain notify-send, which has no real name
                            readonly property string app: parent.parent.modelData.appName || ""
                            visible: app.length > 0 && app !== "notify-send"
                            text: app.toUpperCase()
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
                        Row {   // the sender's buttons («Rydd opp», «Undo» …): the first is the main one, in gold
                            visible: parent.parent.modelData.actions.length > 0
                            topPadding: 6
                            spacing: 8
                            Repeater {
                                model: parent.parent.parent.modelData.actions
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: label.implicitWidth + 24; height: 28
                                    color: index === 0 ? notes.theme.gold : notes.theme.raised
                                    border.color: index === 0 ? notes.theme.gold : notes.theme.line
                                    Text {
                                        id: label
                                        anchors.centerIn: parent
                                        text: parent.modelData.text
                                        font { family: notes.theme.mono; pixelSize: 12; bold: true }
                                        color: parent.index === 0 ? notes.theme.bg : notes.theme.text
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
