// AI agents (olymparch-mcp): the approval card. An agent that wants to change something (or read something
// private) waits until you answer here: «Tillat én gang», «Alltid for KLIENT/VERKTØY» or «Avvis»; 60 s without an
// answer is a no. olymparch-mcp asks through IPC and reads your answer from a file only it and the shell use:
//   qs ipc -p /usr/share/olymparch/shell call mcp ask ID CLIENT TRANSPORT TOOL TITLE RISK SUMMARY → shown | game | off
//   qs ipc -p /usr/share/olymparch/shell call mcp cancel ID          (the agent left, or the time ran out)
//   qs ipc -p /usr/share/olymparch/shell call mcp pending            → the ids on screen (tests)
// There is deliberately no IPC call that answers: only a mouse click on the card does. The card never takes the
// keyboard (an Enter meant for a game or a chat can't approve), its buttons wake up after a moment (a click meant for
// what was under it doesn't count), and it is a layer of the shell, not a window: the agents' window tools can't
// reach it. While a game runs (spillmodus) no card is shown: olymparch-mcp is told «game» and says no at once.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: mcp
    required property var theme
    property bool gameActive: false
    readonly property int seconds: 60
    readonly property string answers: (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/olymparch-mcp/answers"
    property var requests: []          // [{ id, client, transport, tool, title, risk, summary, started }]
    property real now: Date.now()

    function drop(id) { requests = requests.filter(r => r.id !== id); }
    function answer(r, decision) {
        if (!Quickshell.env("XDG_RUNTIME_DIR")) return;
        const f = answerFile.createObject(mcp, { path: mcp.answers + "/" + r.id });
        f.setText(r.id + " " + decision + "\n");
        f.destroy();
        drop(r.id);
    }
    Component {
        id: answerFile
        FileView { atomicWrites: true; blockWrites: true; printErrors: false }
    }

    IpcHandler {
        target: "mcp"
        function ask(id: string, client: string, transport: string, tool: string, title: string, risk: string, summary: string): string {
            if (!/^[0-9a-f]{32}$/.test(id)) return "bad";
            if (Settings.get("ai.enabled") === false) return "off";
            if (mcp.gameActive) return "game";
            // nothing that changes how text looks: control characters (C0, C1), bidi overrides, zero-width, line breaks
            const bad = /[\u0000-\u001f\u007f-\u009f\u061c\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff\ufff9-\ufffb]/g;
            const clean = (s, n) => String(s).replace(bad, " ").replace(/ {2,}/g, " ").trim().slice(0, n);
            const titles = String(title).split("\u001f");   // «English␟norsk», both fixed strings in olymparch-mcp
            const shownTitle = I18n.lang === "nb" && titles.length > 1 ? titles[1] : titles[0];
            const lines = String(summary).split("\n").slice(0, 6).map(l => clean(l, 90)).filter(l => l.length > 0);
            mcp.requests = mcp.requests.filter(r => r.id !== id).concat([{
                id: id, client: clean(client, 40), transport: transport === "http" ? "http" : "stdio",
                tool: clean(tool, 48), title: clean(shownTitle, 60), risk: risk === "sensitive" ? "sensitive" : "change",
                summary: lines.join("\n"), started: Date.now()
            }]);
            return "shown";
        }
        function cancel(id: string): void { mcp.drop(id); }
        function pending(): string { return JSON.stringify(mcp.requests.map(r => r.id)); }
    }

    Timer {   // the countdown, and the shell's own end of a request (olymparch-mcp has already said no by then)
        interval: 250
        repeat: true
        running: mcp.requests.length > 0
        onTriggered: {
            mcp.now = Date.now();
            const old = mcp.requests.filter(r => mcp.now - r.started > (mcp.seconds + 1) * 1000);
            for (const r of old) mcp.drop(r.id);
        }
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: mcp.requests.length > 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-mcp-approval"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true }
        margins { top: 46 }
        implicitWidth: 480
        implicitHeight: cards.implicitHeight
        color: "transparent"

        Column {
            id: cards
            width: parent.width
            spacing: 10
            Repeater {
                model: mcp.requests.slice(0, 3)
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool sensitive: modelData.risk === "sensitive"
                    readonly property color accent: sensitive ? mcp.theme.red : mcp.theme.gold
                    readonly property int remaining: Math.max(0, Math.ceil(mcp.seconds - (mcp.now - modelData.started) / 1000))
                    property bool armed: false
                    Timer { interval: 900; running: true; onTriggered: card.armed = true }
                    width: cards.width
                    height: body.implicitHeight + 28
                    color: mcp.theme.bg
                    border.color: card.accent
                    border.width: 1
                    Rectangle { width: 4; height: parent.height; color: card.accent }

                    Column {
                        id: body
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; leftMargin: 20 }
                        spacing: 6
                        Item {
                            width: parent.width
                            height: head.implicitHeight
                            Row {
                                id: head
                                spacing: 8
                                Text {
                                    text: ""
                                    font { family: "Symbols Nerd Font Mono"; pixelSize: mcp.theme.px(14) }
                                    color: mcp.theme.gold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: I18n.t("mcp.asks", "AN AI AGENT ASKS")
                                    font { family: mcp.theme.mono; pixelSize: mcp.theme.px(11); bold: true; letterSpacing: 1.5 }
                                    color: mcp.theme.gold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Rectangle {   // what kind of call: a change, or something private
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                width: badge.implicitWidth + 14; height: badge.implicitHeight + 6
                                color: "transparent"
                                border.color: card.accent
                                Text {
                                    id: badge
                                    anchors.centerIn: parent
                                    text: card.sensitive ? I18n.t("mcp.sensitive", "PRIVATE") : I18n.t("mcp.change", "CHANGE")
                                    font { family: mcp.theme.mono; pixelSize: mcp.theme.px(10); bold: true; letterSpacing: 1 }
                                    color: card.accent
                                }
                            }
                        }
                        Text {   // who: the name is what the agent says it is; the transport is ours
                            width: parent.width
                            text: card.modelData.client + "  ·  " + card.modelData.transport + "  " + I18n.t("mcp.self_named", "(name given by the client)")
                            font { family: mcp.theme.mono; pixelSize: mcp.theme.px(12) }
                            color: mcp.theme.muted
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        Text {
                            width: parent.width
                            text: card.modelData.title
                            font { family: mcp.theme.mono; pixelSize: mcp.theme.px(15); bold: true }
                            color: mcp.theme.text
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                        Text {   // what follows comes from the agent: framed, plain text, one line per field
                            visible: card.modelData.summary.length > 0
                            text: I18n.t("mcp.arguments", "ARGUMENTS FROM THE AGENT")
                            font { family: mcp.theme.mono; pixelSize: mcp.theme.px(10); bold: true; letterSpacing: 1 }
                            color: mcp.theme.muted
                        }
                        Rectangle {   // exactly what it wants to do
                            visible: card.modelData.summary.length > 0
                            width: parent.width
                            height: visible ? what.implicitHeight + 14 : 0
                            color: mcp.theme.surface
                            border.color: mcp.theme.line
                            Text {
                                id: what
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 9 }
                                text: card.modelData.summary
                                font { family: mcp.theme.mono; pixelSize: mcp.theme.px(12) }
                                color: mcp.theme.text
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 12
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }
                        Text {
                            text: I18n.t("mcp.tool", "Tool: %1").arg(card.modelData.tool)
                            font { family: mcp.theme.mono; pixelSize: mcp.theme.px(10) }
                            color: mcp.theme.muted
                            textFormat: Text.PlainText
                        }
                        Flow {
                            width: parent.width
                            spacing: 8
                            topPadding: 4
                            Repeater {
                                model: [
                                    { how: "once", text: I18n.t("mcp.once", "Allow once"), main: true },
                                    { how: "deny", text: I18n.t("mcp.deny", "Deny"), main: false },
                                    { how: "always", text: I18n.t("mcp.always", "Always for %1").arg(card.modelData.client + "/" + card.modelData.tool), main: false }
                                ]
                                delegate: Rectangle {
                                    id: btn
                                    required property var modelData
                                    width: Math.min(label.implicitWidth + 24, body.width)
                                    height: 30
                                    opacity: card.armed ? 1 : 0.45
                                    color: modelData.main ? (area.containsMouse && card.armed ? mcp.theme.goldHi : mcp.theme.gold)
                                        : (area.containsMouse && card.armed ? mcp.theme.surface : mcp.theme.raised)
                                    border.color: modelData.main ? mcp.theme.gold : (area.containsMouse && card.armed ? mcp.theme.gold : mcp.theme.line)
                                    Text {
                                        id: label
                                        anchors.centerIn: parent
                                        width: Math.min(implicitWidth, body.width - 24)
                                        elide: Text.ElideMiddle
                                        text: btn.modelData.text
                                        font { family: mcp.theme.mono; pixelSize: mcp.theme.px(12); bold: true }
                                        color: btn.modelData.main ? mcp.theme.bg : mcp.theme.text
                                        textFormat: Text.PlainText
                                    }
                                    MouseArea {
                                        id: area
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: card.armed ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: if (card.armed) mcp.answer(card.modelData, btn.modelData.how)
                                    }
                                }
                            }
                        }
                        Item {   // time left: a bar that runs down, and the seconds
                            width: parent.width
                            height: 16
                            Rectangle { y: 2; width: parent.width; height: 2; color: mcp.theme.line }
                            Rectangle { y: 2; width: parent.width * card.remaining / mcp.seconds; height: 2; color: card.accent }
                            Text {
                                anchors { right: parent.right; bottom: parent.bottom }
                                text: I18n.t("mcp.left", "Denied in %1 s").arg(card.remaining)
                                font { family: mcp.theme.mono; pixelSize: mcp.theme.px(10) }
                                color: mcp.theme.muted
                            }
                        }
                    }
                }
            }
        }
    }
}
