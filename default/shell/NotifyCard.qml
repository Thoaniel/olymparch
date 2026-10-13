// One notification toast (Notifications.qml): the sender with its icon, the summary, the body (bold/italic kept, links
// and other markup made plain), an attached image, the sender's buttons, an answer field for apps that take one
// (inline reply), and a thin line that runs out with the time it stays. The mouse over it pauses the time.
// A click on the card does what the sender meant by a click (its «default» action, often: open the chat/mail/tab),
// else it goes to the app's window; it never closes it by surprise. × or a right click closes, a middle click
// closes them all. A sender's avatar (a small square picture, as chat apps send) sits small left of the title.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

Rectangle {
    id: card
    required property var modelData
    required property var theme
    required property int duration          // ms; 0 = stays until answered or closed
    property bool newest: false
    property var arrived: new Date()
    signal closeAll
    readonly property bool hovered: hover.containsMouse || closeArea.containsMouse || reply.activeFocus
    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") || null
    readonly property var buttons: modelData.actions.filter(a => a.identifier !== "default")
    color: theme.surface
    border.color: critical ? theme.red : theme.line
    height: body.implicitHeight + 24
    clip: true

    // ── slides in from the side it sits on
    property real slide: 1
    transform: Translate { x: card.slide * 40 }
    opacity: 1 - card.slide
    Component.onCompleted: slide = 0
    Behavior on slide { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // ── the time it stays, paused under the mouse (and while you write an answer)
    property real elapsed: 0
    readonly property bool paused: hover.containsMouse || reply.activeFocus
    Timer {
        running: card.duration > 0 && !card.paused
        interval: 100; repeat: true
        onTriggered: { card.elapsed += 100; if (card.elapsed >= card.duration) { try { card.modelData.expire(); } catch (e) {} } }
    }

    // markup the specification allows: keep b/i/u and line breaks, make the rest (links, images, spans) plain text
    function clean(s) {
        return String(s || "")
            .replace(/<\s*br\s*\/?>/gi, "\n")
            .replace(/<(?!\/?(b|i|u)>)[^>]*>/gi, "")
            .replace(/\n/g, "<br>");
    }
    readonly property bool iconOnly: /^image:\/\/icon\/[^\/]/.test(modelData.image || "")
    readonly property string iconName: modelData.appIcon || (iconOnly ? String(modelData.image).replace(/^image:\/\/icon\//, "") : "")
    function iconSource(name) {
        if (!name) return "";
        if (name.startsWith("/")) return "file://" + name;
        if (/^(file|image|qrc):/.test(name)) return name;
        return Quickshell.iconPath(name, true);
    }

    // the app's open window (by its desktop entry or name), for a click when the sender gave no default action
    function appWindow() {
        const want = [modelData.desktopEntry, modelData.appName].filter(x => x).map(x => String(x).toLowerCase().replace(/\.desktop$/, ""));
        return ToplevelManager.toplevels.values.find(t => {
            const id = String(t.appId || "").toLowerCase();
            return want.some(w => id === w || id.endsWith("." + w) || w.endsWith("." + id));
        }) || null;
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: card.defaultAction || card.appWindow() ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => {
            if (m.button === Qt.RightButton) { card.modelData.dismiss(); return; }
            if (m.button === Qt.MiddleButton) { card.closeAll(); return; }
            if (card.defaultAction) { card.defaultAction.invoke(); return; }
            const w = card.appWindow();
            if (w) { w.activate(); card.modelData.dismiss(); }
        }
    }
    // when it came: «now», «3 min», then the time
    property int tick: 0
    Timer { interval: 30000; running: true; repeat: true; onTriggered: card.tick++ }
    readonly property string age: {
        card.tick;
        const m = Math.floor((Date.now() - arrived.getTime()) / 60000);
        return m < 1 ? I18n.t("notify.now", "now") : m < 60 ? m + " min" : Qt.formatTime(arrived, "HH:mm");
    }
    Rectangle { width: 3; height: parent.height; color: card.critical ? card.theme.red : card.theme.gold }
    // the time left, as a line along the bottom
    Rectangle {
        visible: card.duration > 0
        anchors.bottom: parent.bottom
        x: 3; height: 2
        width: (parent.width - 3) * Math.max(0, 1 - card.elapsed / Math.max(1, card.duration))
        color: card.theme.gold
        opacity: card.paused ? 0.3 : 0.8
    }
    // × closes (shown under the mouse, and always on the ones that stay until answered)
    Text {
        z: 2
        visible: hover.containsMouse || closeArea.containsMouse || card.duration === 0
        anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 8 }
        text: "\u{F0156}"
        font { family: "Symbols Nerd Font Mono"; pixelSize: card.theme.px(14) }
        color: closeArea.containsMouse ? card.theme.goldHi : card.theme.muted
        MouseArea { id: closeArea; anchors { fill: parent; margins: -6 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.modelData.dismiss() }
    }

    // a small square picture (≤ 160 px, as chat and mail apps send for the sender) is an avatar, not an attachment
    readonly property bool avatar: attached.status === Image.Ready && attached.implicitWidth <= 160
                                   && Math.abs(attached.implicitWidth - attached.implicitHeight) <= attached.implicitWidth * 0.15
    Image {
        visible: card.avatar
        x: 16; y: 14
        width: 40; height: 40
        source: attached.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    Column {
        id: body
        z: 1   // above the card's own click area, so buttons and the answer field get theirs
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: card.avatar ? 16 + 40 + 10 : 16; rightMargin: 28 }
        spacing: 3
        Row {   // the sender with its icon; left out for plain notify-send, which has no real name
            readonly property string app: card.modelData.appName || ""
            visible: app.length > 0 && app !== "notify-send"
            spacing: 6
            Image {
                id: appIcon
                source: card.iconSource(card.iconName)
                visible: source != "" && status === Image.Ready
                width: card.theme.px(14); height: width
                sourceSize { width: 32; height: 32 }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: (card.critical ? "⚠ " : "") + parent.app + "  ·  " + card.age
                font { family: card.theme.mono; pixelSize: card.theme.px(11) }
                color: card.theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            width: parent.width
            text: card.modelData.summary
            font { family: card.theme.mono; pixelSize: card.theme.px(14); bold: true }
            color: card.theme.text
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        Text {
            width: parent.width
            visible: card.modelData.body.length > 0
            text: card.clean(card.modelData.body)
            font { family: card.theme.mono; pixelSize: card.theme.px(13) }
            color: card.theme.muted
            wrapMode: Text.Wrap
            maximumLineCount: 5
            elide: Text.ElideRight
            textFormat: Text.StyledText
        }
        Rectangle {   // an image the sender attached (a screenshot, a cover, a colour swatch), framed in line
            visible: attached.src.length > 0 && attached.status === Image.Ready && !card.avatar
            width: attached.width + 2
            height: visible ? attached.height + 2 : 0
            color: "transparent"
            border.color: card.theme.line
            Image {
                id: attached
                x: 1; y: 1
                // a file path comes as image://icon/PATH, which the icon provider loads at 2×2: load the file
                // an icon *name* (image://icon/steam) is the app's icon, not a picture: it goes small by the app's name
                readonly property string src: card.iconOnly ? "" : (card.modelData.image || "").replace(/^image:\/\/icon\/(?=\/)/, "")
                source: src.length === 0 ? "" : src.startsWith("/") ? "file://" + src : src
                // never larger than it is (a swatch stays 96×32), at most the card's width and 140 px high
                width: Math.min(body.width - 2, implicitWidth, implicitWidth * 140 / Math.max(1, implicitHeight))
                height: width * implicitHeight / Math.max(1, implicitWidth)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
        }
        // an answer straight from the toast (chat apps that offer it): Enter sends
        Rectangle {
            visible: card.modelData.hasInlineReply
            width: parent.width; height: card.theme.px(28)
            color: card.theme.bg
            border.color: reply.activeFocus ? card.theme.gold : card.theme.line
            TextInput {
                id: reply
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter
                font { family: card.theme.mono; pixelSize: card.theme.px(12) }
                color: card.theme.text
                clip: true
                onAccepted: { const t = text.trim(); if (t) card.modelData.sendInlineReply(t); text = ""; }
                Text {
                    visible: !reply.text && !reply.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.modelData.inlineReplyPlaceholder || I18n.t("notify.reply", "Answer …")
                    font: reply.font
                    color: card.theme.muted
                }
            }
        }
        Row {   // the sender's buttons («Rydd opp», «Undo» …): the first is the main one, in gold
            visible: card.buttons.length > 0
            topPadding: 6
            spacing: 8
            Repeater {
                model: card.buttons
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: label.implicitWidth + 24; height: 28
                    color: index === 0 ? card.theme.gold : card.theme.raised
                    border.color: index === 0 ? card.theme.gold : card.theme.line
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: parent.modelData.text
                        font { family: card.theme.mono; pixelSize: card.theme.px(12); bold: true }
                        color: parent.index === 0 ? card.theme.bg : card.theme.text
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.invoke() }
                }
            }
        }
        Text {   // the newest toast with buttons says how to answer it without the mouse
            visible: card.buttons.length > 0 && card.newest
            text: I18n.t("notify.keys", "Super+Shift+Enter: gold button · Super+Shift+Esc: close")
            font { family: card.theme.mono; pixelSize: card.theme.px(10) }
            color: card.theme.muted
        }
    }
}
