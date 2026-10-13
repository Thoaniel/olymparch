// Zeus' approval card outside its panel (B4): when Zeus waits for your yes and the Zeus panel is not open, a card
// under the bar says what it wants to do, with Yes / Yes, don't ask again in this chat / No. Like the AI agents'
// card (McpApproval.qml): it never takes the keyboard (an Enter meant for a game or a chat can't approve), its
// buttons wake up after a moment (a click meant for what was under it doesn't count), and while a game runs it is
// not shown at all (Zeus waits; the bar's gold dot and the panel still have it). Data: Zeus.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: za
    required property var theme
    property bool gameActive: false
    function t(key, en) { return I18n.t(key, en); }
    readonly property bool show: Zeus.approvals.length > 0 && !gameActive && Panels.current !== "zeus"
        && Settings.get("appearance.bar") !== false

    IpcHandler {   // read-only, for the VM tests: is the card on screen (there is no IPC call that answers it)
        target: "zeuscard"
        function shown(): bool { return za.show; }
    }
    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Panels.focusedScreen()) || Quickshell.screens[0]
        visible: za.show
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-zeus-approval"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins { top: 42; right: 12 }
        implicitWidth: za.theme.px(440)
        implicitHeight: card.height
        color: "transparent"

        Rectangle {
            id: card
            readonly property var r: Zeus.approvals.length ? Zeus.approvals[0] : ({})
            readonly property color accent: r.danger ? za.theme.red : za.theme.gold
            property bool armed: false
            onRChanged: { armed = false; arm.restart(); }
            Timer { id: arm; interval: 1200; running: true; onTriggered: card.armed = true }
            width: parent.width
            height: body.implicitHeight + 28
            color: za.theme.bg
            border.color: accent
            Rectangle { width: 4; height: parent.height; color: card.accent }
            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; leftMargin: 20 }
                spacing: 6
                Text {
                    text: "  " + za.t("zeus.approval.card", "ZEUS WANTS TO") + (Zeus.approvals.length > 1 ? "  (" + Zeus.approvals.length + ")" : "")
                    font { family: za.theme.mono; pixelSize: za.theme.px(11); bold: true; letterSpacing: 1.5 }
                    color: za.theme.gold
                }
                Text {
                    width: parent.width
                    text: (card.r.danger ? "⚠ " : "") + (String(card.r.reason || card.r.tool || "").replace(/^./, c => c.toUpperCase()))
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font { family: za.theme.mono; pixelSize: za.theme.px(13); bold: true }
                    color: card.r.danger ? za.theme.red : za.theme.text
                }
                Text {
                    visible: !!card.r.preview
                    width: parent.width
                    text: card.r.preview || ""
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    wrapMode: Text.WrapAnywhere
                    font { family: za.theme.mono; pixelSize: za.theme.px(12) }
                    color: za.theme.muted
                }
                Row {
                    spacing: za.theme.px(18)
                    topPadding: 4
                    Repeater {
                        model: [
                            { id: "yes", text: za.t("zeus.approval.yes", "Yes, do it") },
                            card.r.danger ? null : { id: "always", text: za.t("zeus.approval.always_short", "Yes, always in this chat") },
                            { id: "no", text: za.t("zeus.approval.no", "No"), danger: true },
                            { id: "open", text: za.t("zeus.approval.open", "Open Zeus") }
                        ].filter(x => x)
                        delegate: Text {
                            id: btn
                            required property var modelData
                            text: modelData.text
                            opacity: card.armed ? 1 : 0.4
                            font { family: za.theme.mono; pixelSize: za.theme.px(13); bold: true; underline: m.containsMouse && card.armed }
                            color: modelData.danger ? za.theme.red : m.containsMouse && card.armed ? za.theme.goldHi : za.theme.gold
                            MouseArea {
                                id: m
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: card.armed
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const id = card.r.id;
                                    if (btn.modelData.id === "yes") Zeus.approve(id);
                                    else if (btn.modelData.id === "always") Zeus.always(id);
                                    else if (btn.modelData.id === "no") Zeus.deny(id);
                                    else Panels.open("zeus", "");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
