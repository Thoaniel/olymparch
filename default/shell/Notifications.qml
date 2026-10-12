// The notification server: the shell is the only one (no mako, dunst or swaync). Toasts top right under the
// bar, at most as many as Settings says, for as long as it says (ones with buttons and critical ones stay until
// answered or dismissed); all of it is in Settings → Notifications. Do not disturb hides everything but critical.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Hyprland

Scope {
    id: notes
    required property var theme
    property bool dnd: false   // shell.qml: Settings → do not disturb (also the bell in the bar), or spillmodus
    property bool silent: false   // a game runs and Settings says none: even critical ones wait (kept, shown after)
    readonly property string position: Settings.get("notifications.position")
    readonly property bool top: position.startsWith("top")
    readonly property bool left: position.endsWith("left")
    readonly property var shown: server.trackedNotifications.values
        .filter(n => !silent && (!dnd || n.urgency === NotificationUrgency.Critical))
        .slice(-Settings.get("notifications.max_visible")).reverse()

    // ── Settings → Notifications → Muted apps: names in settings.json; every app that notifies is remembered in
    //    ~/.local/state/olymparch/notification-apps.json so the list there can offer it (olymparch-settings items)
    readonly property var muted: Settings.get("notifications.apps") || []
    FileView {
        id: seenApps
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/olymparch/notification-apps.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
    function remember(app) {
        if (!app || app.length > 80) return;
        let list = [];
        try { list = JSON.parse(seenApps.text() || "[]"); } catch (e) { list = []; }
        if (!Array.isArray(list) || list.includes(app)) return;
        list.push(app);
        seenApps.setText(JSON.stringify(list.slice(-100)));
    }

    NotificationServer {
        id: server
        keepOnReload: true
        imageSupported: true   // images senders attach (the tools: a screenshot, a colour swatch)
        actionsSupported: true
        bodySupported: true
        onNotification: n => {
            const critical = n.urgency === NotificationUrgency.Critical;
            notes.remember(n.appName || "");
            if (notes.dnd && !critical) return;   // not tracked: dropped quietly
            if (!critical && notes.muted.includes(n.appName || "")) return;   // a muted app (Settings → Notifications)
            n.tracked = true;
            // offers with buttons («Install driver», «Undo» …) stay until answered, like critical ones
            // (a sender that sets its own timeout gets it even with buttons: the tools' «Edit» / «Open folder»)
            const own = n.expireTimeout > 600 ? n.expireTimeout / 1000 : n.expireTimeout > 0 ? n.expireTimeout : 0;   // s (ms from some servers)
            if (!critical && (n.actions.length === 0 || own > 0)) {
                const t = Qt.createQmlObject(`import QtQuick; Timer { interval: ${own > 0 ? Math.round(own * 1000) : Settings.get("notifications.duration") * 1000}; running: true }`, notes);
                // the toast may be gone already (dismissed)
                t.triggered.connect(() => { try { if (n) n.expire(); } catch (e) {} t.destroy(); });
            }
        }
    }

    // ── the keyboard (keys.notification_action / keys.notification_dismiss): the newest toast's main button, or away
    GlobalShortcut {
        appid: "olymparch"
        name: "notification-action"
        description: "Press the main button of the newest notification"
        onPressed: { const n = notes.shown[0]; if (n && n.actions.length > 0) n.actions[0].invoke(); }
    }
    GlobalShortcut {
        appid: "olymparch"
        name: "notification-dismiss"
        description: "Dismiss the newest notification"
        onPressed: { const n = notes.shown[0]; if (n) n.dismiss(); }
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
                            font { family: notes.theme.mono; pixelSize: notes.theme.px(11); letterSpacing: 1.5; bold: true }
                            color: parent.parent.critical ? notes.theme.red : notes.theme.gold
                        }
                        Text {
                            width: parent.width
                            text: parent.parent.modelData.summary
                            font { family: notes.theme.mono; pixelSize: notes.theme.px(14); bold: true }
                            color: notes.theme.text
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: parent.parent.modelData.body
                            font { family: notes.theme.mono; pixelSize: notes.theme.px(13) }
                            color: notes.theme.muted
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        Rectangle {   // an image the sender attached (a screenshot, a colour swatch), framed in line
                            visible: attached.src.length > 0 && attached.status === Image.Ready
                            width: attached.width + 2
                            height: visible ? attached.height + 2 : 0
                            color: "transparent"
                            border.color: notes.theme.line
                            Image {
                                id: attached
                                x: 1; y: 1
                                // a file path comes as image://icon/PATH, which the icon provider loads at 2×2: load the file
                                readonly property string src: (parent.parent.parent.modelData.image || "").replace(/^image:\/\/icon\/(?=\/)/, "")
                                source: src.length === 0 ? "" : src.startsWith("/") ? "file://" + src : src
                                // never larger than it is (a swatch stays 96×32), at most the card's width and 140 px high
                                width: Math.min(parent.parent.width - 2, implicitWidth, implicitWidth * 140 / Math.max(1, implicitHeight))
                                height: width * implicitHeight / Math.max(1, implicitWidth)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                            }
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
                                        font { family: notes.theme.mono; pixelSize: notes.theme.px(12); bold: true }
                                        color: parent.index === 0 ? notes.theme.bg : notes.theme.text
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: parent.modelData.invoke() }
                                }
                            }
                        }
                        Text {   // the newest toast with buttons says how to answer it without the mouse
                            visible: parent.parent.modelData.actions.length > 0 && notes.shown[0] === parent.parent.modelData
                            text: I18n.t("notify.keys", "Super+Shift+Enter: gold button · Super+Shift+Esc: close")
                            font { family: notes.theme.mono; pixelSize: notes.theme.px(10) }
                            color: notes.theme.muted
                        }
                    }
                    MouseArea { anchors.fill: parent; z: -1; onClicked: parent.modelData.dismiss() }
                }
            }
        }
    }
}
