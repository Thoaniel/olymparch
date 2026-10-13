// Settings → AI → Services (B2): every AI service Zeus and the agents can use, in one place, with what it needs.
// One line each: the name, Free / Subscription, and its state (ready, needs a key, not signed in, not installed),
// with the one action that state calls for. Keys are typed into a hidden field and go to `olymparch-keys set`
// on its stdin (Secret Service, else a 0600 file): never argv, a log or the audit. «Sign in» opens the tool's own
// login in foot. Data: `olympus providers --json` (one block per provider in Olympus' config.toml).
import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: list
    required property var theme
    property var services: []
    property bool loaded: false
    property bool olympus: true
    property string editing: ""        // the service whose key field is open
    property string saved: ""          // «Saved for groq» for a moment
    spacing: 2
    function t(key, en) { return I18n.t(key, en); }
    readonly property string bin: Quickshell.env("OLYMPARCH_OLYMPUS") || Quickshell.env("HOME") + "/.local/bin/olympus"

    function load() { probe.running = false; probe.running = true; }
    Component.onCompleted: load()
    onVisibleChanged: if (visible) load()

    Process {
        id: probe
        command: [list.bin, "providers", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { list.services = JSON.parse(text) || []; list.olympus = true; } catch (e) { list.services = []; }
                list.loaded = true;
            }
        }
        onExited: code => { if (code !== 0) { list.olympus = false; list.loaded = true; } }
    }
    Process {
        id: store
        property string name: ""
        property string key: ""
        command: ["olymparch-keys", "set", name]
        stdinEnabled: true
        onStarted: { write(key + "\n"); key = ""; stdinEnabled = false; }
        onExited: code => { list.saved = code === 0 ? name : ""; list.editing = ""; list.load(); savedTimer.restart(); }
    }
    Timer { id: savedTimer; interval: 4000; onTriggered: list.saved = "" }
    function saveKey(name, key) {
        key = String(key || "").trim();
        if (!key || store.running) return;
        store.name = name; store.key = key; store.stdinEnabled = true; store.running = true;
    }

    readonly property var words: ({
        ready: t("services.ready", "Ready"), missing_key: t("services.missing_key", "Needs a key"),
        not_logged_in: t("services.not_logged_in", "Not signed in"), not_installed: t("services.not_installed", "Not installed")
    })

    Text {
        visible: list.loaded && !list.olympus
        width: list.width
        text: list.t("services.no_olympus", "Zeus (Olympus) is not installed: Settings → Zeus and AI → Install Zeus.")
        wrapMode: Text.Wrap
        font { family: list.theme.mono; pixelSize: list.theme.px(12) }
        color: list.theme.muted
    }
    Repeater {
        model: list.services.filter(s => s.type !== "anthropic" || s.status === "ready")   // per-token API: only when set up
        delegate: Column {
            id: svc
            required property var modelData
            readonly property var s: modelData
            readonly property bool open: list.editing === s.id
            width: list.width
            spacing: 4
            bottomPadding: 6
            Item {
                width: parent.width
                height: list.theme.px(26)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text {
                        text: svc.s.label
                        font { family: list.theme.mono; pixelSize: list.theme.px(13); bold: true }
                        color: list.theme.text
                    }
                    Text {   // the badge: free, or a subscription you already pay for
                        visible: svc.s.free || svc.s.subscription
                        text: svc.s.free ? list.t("services.free", "Free") : list.t("services.subscription", "Subscription")
                        font { family: list.theme.mono; pixelSize: list.theme.px(11); letterSpacing: 1 }
                        color: svc.s.free ? list.theme.gold : list.theme.muted
                    }
                    Text {
                        text: "·  " + (list.saved === svc.s.id ? list.t("services.saved", "Key saved") : (list.words[svc.s.status] || svc.s.status))
                        font { family: list.theme.mono; pixelSize: list.theme.px(12) }
                        color: svc.s.status === "ready" ? list.theme.goldHi : list.theme.muted
                    }
                }
                Row {   // the one action this state calls for, and the link to get a key
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 14
                    Repeater {
                        model: [
                            svc.s.type === "openai" ? { id: "key", text: svc.s.status === "ready" ? list.t("services.change_key", "Change key") : list.t("services.add_key", "Add key") } : null,
                            svc.s.status === "not_logged_in" && svc.s.login.length ? { id: "login", text: list.t("services.login", "Sign in") } : null,
                            svc.s.signup && svc.s.status !== "ready" ? { id: "signup", text: svc.s.type === "openai" ? list.t("services.get_key", "Get a key ↗") : list.t("services.how", "How ↗") } : null
                        ].filter(a => a)
                        delegate: Text {
                            id: act
                            required property var modelData
                            text: modelData.text
                            activeFocusOnTab: true
                            font { family: list.theme.mono; pixelSize: list.theme.px(12); underline: actMouse.containsMouse || activeFocus }
                            color: actMouse.containsMouse || activeFocus ? list.theme.goldHi : list.theme.gold
                            function go() {
                                if (modelData.id === "key") list.editing = svc.open ? "" : svc.s.id;
                                else if (modelData.id === "login") Quickshell.execDetached(["foot", "-H", "--"].concat(svc.s.login));
                                else if (/^https:\/\//.test(svc.s.signup)) Quickshell.execDetached(["xdg-open", svc.s.signup]);
                            }
                            Keys.onReturnPressed: go()
                            Keys.onSpacePressed: go()
                            MouseArea { id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: act.go() }
                        }
                    }
                }
            }
            Text {
                visible: !!svc.s.note
                width: parent.width
                text: svc.s.note
                wrapMode: Text.Wrap
                font { family: list.theme.mono; pixelSize: list.theme.px(11) }
                color: list.theme.muted
            }
            // the key: hidden, Enter saves it, Esc closes; it is kept nowhere in the shell
            Rectangle {
                visible: svc.open
                width: Math.min(parent.width, list.theme.px(460))
                height: list.theme.px(28)
                color: list.theme.field
                border.color: keyField.activeFocus ? list.theme.gold : list.theme.line
                TextInput {
                    id: keyField
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    font { family: list.theme.mono; pixelSize: list.theme.px(13) }
                    color: list.theme.text
                    clip: true
                    onVisibleChanged: { text = ""; if (visible) forceActiveFocus(); }
                    Keys.onReturnPressed: { list.saveKey(svc.s.id, text); text = ""; }
                    Keys.onEnterPressed: { list.saveKey(svc.s.id, text); text = ""; }
                    Keys.onEscapePressed: { text = ""; list.editing = ""; }
                    Text {
                        visible: !keyField.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: list.t("services.key_hint", "Paste the key, Enter saves it")
                        font: keyField.font
                        color: list.theme.muted
                    }
                }
            }
        }
    }
}
