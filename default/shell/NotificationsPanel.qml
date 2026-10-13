// The Notifications panel (under the bell): do not disturb on/off, the last notifications (also those it held back,
// marked; a click on one goes to the app's window when it is open), clear the list, and the notification settings. The list lives in memory only (NotifyHistory.qml).
import QtQuick
import Quickshell
import Quickshell.Wayland

Dropdown {
    id: p
    name: "notifications"
    icon: "\u{F009A}"
    title: t("notes.title", "Notifications")
    en: "Notifications"
    nb: "Varsler"
    panelWidth: theme.px(440)
    function t(key, en) { return I18n.t(key, en); }
    status: theme.dndSetting ? t("notes.dnd_on", "Do not disturb is on: only critical ones show") : t("notes.dnd_off", "Notifications show as they come")
    statusTint: theme.dndSetting ? theme.gold : theme.muted
    onOpened: NotifyHistory.seen()

    PanelAction {
        theme: p.theme
        icon: p.theme.dndSetting ? "\u{F009A}" : "\u{F009B}"
        label: p.theme.dndSetting ? p.t("notes.dnd_turn_off", "Turn do not disturb off") : p.t("notes.dnd_turn_on", "Turn do not disturb on")
        onActivated: p.theme.toggleDnd()
    }
    PanelLine { theme: p.theme; heading: true; label: p.t("notes.recent", "Recent") }
    Text {
        visible: NotifyHistory.items.length === 0
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        text: p.t("notes.none", "Nothing since you logged in.")
        font { family: p.theme.mono; pixelSize: p.theme.px(13) }
        color: p.theme.muted
    }
    Repeater {
        model: NotifyHistory.items.slice(0, 8)
        delegate: Item {
            id: entry
            required property var modelData
            readonly property var win: NotifyHistory.windowOf(modelData)
            x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
            implicitHeight: lines.implicitHeight
            height: implicitHeight
            // a click goes to the app's window (when it is open)
            MouseArea {
                anchors.fill: parent
                enabled: !!entry.win
                hoverEnabled: true
                cursorShape: entry.win ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { Panels.close("notifications"); entry.win.activate(); }
            }
            Column {
                id: lines
                width: parent.width
                spacing: 1
                bottomPadding: p.theme.px(6)
                readonly property var modelData: entry.modelData
                Text {
                    width: parent.width
                    text: Qt.formatTime(modelData.time, "HH:mm") + "  " + (modelData.app || "?") + (modelData.held ? "  · " + p.t("notes.held", "held back") : "")
                    elide: Text.ElideRight
                    font { family: p.theme.mono; pixelSize: p.theme.px(11); letterSpacing: 0.5 }
                    color: modelData.critical ? p.theme.red : p.theme.muted
                }
                Text {
                    width: parent.width
                    text: modelData.summary
                    elide: Text.ElideRight
                    font { family: p.theme.mono; pixelSize: p.theme.px(13); bold: true }
                    color: p.theme.text
                }
                Text {
                    visible: !!modelData.body
                    width: parent.width
                    text: modelData.body
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    font { family: p.theme.mono; pixelSize: p.theme.px(12) }
                    color: p.theme.muted
                }
            }
        }
    }
    PanelAction { theme: p.theme; visible: NotifyHistory.items.length > 0; icon: ""; label: p.t("notes.clear", "Clear the list"); onActivated: NotifyHistory.clear() }
    PanelAction { theme: p.theme; icon: ""; label: p.t("notes.settings", "Notification settings"); onActivated: { Panels.close("notifications"); Quickshell.execDetached(["olymparch-settings", "open", "notifications"]); } }
}
