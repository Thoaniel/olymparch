// The notification server: the shell is the only one (no mako, dunst or swaync). Toasts on the monitor you work on,
// in the corner Settings says, at most as many as it says («+N more» under them), for as long as it says (ones with
// buttons and critical ones stay until answered or dismissed; the mouse over one pauses it). A toast (NotifyCard.qml)
// shows the app's icon, keeps bold/italic, takes an answer when the app offers one, and a click on it does what the
// app meant by a click. Do not disturb hides everything but critical. All of it is in Settings → Notifications.
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
    readonly property var waiting: server.trackedNotifications.values
        .filter(n => !silent && (!dnd || n.urgency === NotificationUrgency.Critical))
    readonly property var live: waiting.slice(-Settings.get("notifications.max_visible")).reverse()
    // while the mouse is over a toast the stack stands still (a new one would push the card you aim at): new ones
    // wait until the mouse leaves; closed ones still go
    property bool hovering: false
    property var frozen: []
    onHoveringChanged: if (hovering) frozen = live
    readonly property var kept: frozen.filter(n => waiting.includes(n))
    readonly property var shown: hovering && kept.length > 0 ? kept : live
    property var arrived: ({})   // id → Date, for «3 min» on the toast
    property bool replying: false   // a card's answer field has been clicked: the toasts take the keyboard until sent
    // how long each one stays (ms, 0 = until answered), by id: set when it comes, run by its card while it is shown
    property var durations: ({})

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
        bodyMarkupSupported: true    // b/i/u are kept, the rest is made plain (NotifyCard.clean)
        inlineReplySupported: true   // chat apps: answer from the toast
        onNotification: n => {
            const critical = n.urgency === NotificationUrgency.Critical;
            notes.remember(n.appName || "");
            const held = (notes.dnd && !critical) || (!critical && notes.muted.includes(n.appName || ""));
            NotifyHistory.add(n, held);   // the bell's panel lists it, held back or not
            if (notes.dnd && !critical) return;   // not shown: in the bell's list only
            if (!critical && notes.muted.includes(n.appName || "")) return;   // a muted app (Settings → Notifications)
            n.tracked = true;
            // offers with buttons («Install driver», «Undo» …) stay until answered, like critical ones
            // (a sender that sets its own timeout gets it even with buttons: the tools' «Edit» / «Open folder»)
            const own = n.expireTimeout > 600 ? n.expireTimeout / 1000 : n.expireTimeout > 0 ? n.expireTimeout : 0;   // s (ms from some servers)
            const buttons = n.actions.filter(a => a.identifier !== "default").length;
            const ms = critical || n.resident || (buttons > 0 && own <= 0) ? 0
                     : own > 0 ? Math.round(own * 1000) : Settings.get("notifications.duration") * 1000;
            const d = Object.assign({}, notes.durations); d[n.id] = ms; notes.durations = d;
            const t = Object.assign({}, notes.arrived); t[n.id] = new Date(); notes.arrived = t;
            const id = n.id;
            n.closed.connect(() => {
                const d2 = Object.assign({}, notes.durations); delete d2[id]; notes.durations = d2;
                const t2 = Object.assign({}, notes.arrived); delete t2[id]; notes.arrived = t2;
            });
        }
    }

    // ── the keyboard (keys.notification_action / keys.notification_dismiss): the newest toast's main button, or away
    GlobalShortcut {
        appid: "olymparch"
        name: "notification-action"
        description: "Press the main button of the newest notification"
        onPressed: {
            const n = notes.shown[0];
            if (!n) return;
            const a = n.actions.find(x => x.identifier !== "default") || n.actions.find(x => x.identifier === "default");
            if (a) a.invoke();
        }
    }
    GlobalShortcut {
        appid: "olymparch"
        name: "notification-dismiss"
        description: "Dismiss the newest notification"
        onPressed: { const n = notes.shown[0]; if (n) n.dismiss(); }
    }

    PanelWindow {
        // the monitor you work on (where the mouse and keyboard are), else the first
        screen: Quickshell.screens.find(x => Hyprland.focusedMonitor && x.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0]
        visible: notes.shown.length > 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-notifications"
        // never takes the keyboard when a toast comes (you may be typing or playing); only while you write an answer
        // after clicking into its field (NotifyCard.replying), and it gives it back when you send or press Esc
        WlrLayershell.keyboardFocus: notes.replying ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: notes.top; bottom: !notes.top; left: notes.left; right: !notes.left }
        margins { top: 42; bottom: 10; left: 10; right: 12 }
        implicitWidth: 380
        implicitHeight: column.implicitHeight
        color: "transparent"

        Column {
            id: column
            width: parent.width
            spacing: 8
            Repeater {
                model: notes.shown
                delegate: NotifyCard {
                    required property int index
                    theme: notes.theme
                    width: column.width
                    duration: notes.durations[modelData.id] !== undefined ? notes.durations[modelData.id] : Settings.get("notifications.duration") * 1000
                    newest: index === 0
                    arrived: notes.arrived[modelData.id] || new Date()
                    onHoveredChanged: notes.hovering = column.children.some(c => c.hovered === true)
                    onCloseAll: notes.waiting.slice().forEach(n => n.dismiss())
                    onReplyingChanged: notes.replying = column.children.some(c => c.replying === true)
                    Component.onDestruction: if (replying) notes.replying = false
                }
            }
            Text {   // more are waiting behind the ones shown: a click opens the bell's list
                readonly property int more: notes.waiting.length - notes.shown.length
                visible: more > 0
                anchors.right: parent.right
                text: I18n.t("notify.more", "+%1 more").replace("%1", more)
                font { family: notes.theme.mono; pixelSize: notes.theme.px(12); underline: moreArea.containsMouse }
                color: moreArea.containsMouse ? notes.theme.goldHi : notes.theme.gold
                MouseArea {
                    id: moreArea
                    anchors { fill: parent; margins: -6 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.toggle("notifications", Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
                }
            }
        }
    }
}
