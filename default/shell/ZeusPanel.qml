// The Zeus panel (B4): the bar's Zeus item opens it, so do Super+Z, the menu's «Panels» level and
// `qs ipc call panel toggle zeus`. Everything Zeus is, in one place and never in a terminal: what it is doing,
// the conversation and a field to write in, what waits for your yes (right above the field, after the
// conversation it belongs to), which model answers (local, free, or a subscription), AI on/off, and what the
// last answer changed with Undo. Data: Zeus.qml (`olympus bar`).
// Safety: opening the panel never puts the keyboard on «Yes» — it starts in the field (Enter there does not
// approve anything), or on «No» when the request is dangerous.
import QtQuick
import Quickshell

Dropdown {
    id: p
    name: "zeus"
    icon: ""
    title: "Zeus"
    en: "Zeus"
    nb: "Zeus"
    hotkeySetting: "zeus.hotkey"
    panelWidth: theme.px(480)
    function t(key, en) { return I18n.t(key, en); }

    readonly property bool off: Zeus.connected && Zeus.ai === false
    readonly property bool waiting: Zeus.approvals.length > 0
    readonly property bool dangerWaiting: Zeus.approvals.some(a => a.danger)
    status: !Zeus.connected ? t("zeus.status.offline", "Olympus is not answering yet – it starts by itself")
          : off ? t("zeus.status.off", "Off · the graphics card is free")
          : waiting ? t("zeus.status.approval", "Waiting for you")
          : Zeus.state === "thinking" ? t("zeus.status.thinking", "Thinking …")
          : Zeus.answering && Zeus.answering !== Zeus.model ? t("zeus.status.answered_by", "Ready · %1 answered (fallback)").replace("%1", Zeus.answeringProvider)
          : t("zeus.status.idle", "Ready")
    statusTint: waiting ? theme.goldHi : theme.muted
    initialFocus: off ? turnOn : dangerWaiting ? approvalsBox.noButton : ask
    property bool showModels: false
    onOpened: { showModels = false; Zeus.loadModels(); if (!off) Zeus.warm(); }

    function sentence(s) { s = String(s || "").trim(); return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""; }

    // ── off: one sentence and one action, first
    PanelAction {
        id: turnOn
        theme: p.theme
        visible: p.off
        icon: ""
        label: p.t("zeus.on", "Turn Zeus on")
        onActivated: Zeus.setAi(true)
    }

    // ── the conversation: newest at the bottom, the reply streams in; as tall as it needs, at most 360 px
    Item {
        visible: !p.off
        width: p.panelWidth - 2
        height: Zeus.messages.length ? Math.max(p.theme.px(120), Math.min(chat.contentHeight, p.theme.px(360))) : p.theme.px(44)
        Text {
            visible: !Zeus.messages.length
            x: p.theme.px(18); width: parent.width - 2 * x
            anchors.verticalCenter: parent.verticalCenter
            text: p.t("zeus.chat.empty", "Ask Zeus anything. Zeus can use your PC's tools, but asks you first.")
            wrapMode: Text.Wrap
            font { family: p.theme.mono; pixelSize: p.theme.px(13) }
            color: p.theme.muted
        }
        ListView {
            id: chat
            anchors { fill: parent; leftMargin: p.theme.px(18); rightMargin: p.theme.px(12) }
            visible: Zeus.messages.length > 0
            clip: true
            spacing: p.theme.px(16)
            model: Zeus.messages
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: Qt.callLater(positionViewAtEnd)
            onContentHeightChanged: Qt.callLater(positionViewAtEnd)
            delegate: Column {
                required property var modelData
                required property int index
                width: chat.width - p.theme.px(6)
                spacing: p.theme.px(3)
                // the model only when it differs from the previous answer
                readonly property string prevModel: {
                    for (let i = index - 1; i >= 0; i--) if (Zeus.messages[i].kind === "agent") return Zeus.messages[i].model || "";
                    return "";
                }
                Text {
                    text: modelData.kind === "user" ? p.t("zeus.chat.you", "You")
                        : "Zeus" + (modelData.model && modelData.model !== parent.prevModel ? "  ·  " + modelData.model : "")
                    font { family: p.theme.mono; pixelSize: p.theme.px(11); letterSpacing: 1 }
                    color: modelData.kind === "user" ? p.theme.muted : p.theme.gold
                }
                Repeater {   // the tools this answer used, one quiet line each
                    model: modelData.tools || []
                    delegate: Text {
                        required property var modelData
                        width: parent.width
                        text: (modelData.ok === false || modelData.denied ? "✗ " : modelData.ok ? "✓ " : "· ") + modelData.name
                              + (modelData.summary ? "  " + modelData.summary : modelData.detail ? "  " + modelData.detail : "")
                        elide: Text.ElideRight
                        font { family: p.theme.mono; pixelSize: p.theme.px(12) }
                        color: modelData.ok === false || modelData.denied ? p.theme.red : p.theme.muted
                    }
                }
                Text {
                    visible: modelData.text !== "" || modelData.kind === "agent"
                    width: parent.width
                    text: modelData.text || (modelData.rejected ? p.t("zeus.chat.retry", "(trying again …)") : "…")
                    textFormat: modelData.kind === "agent" ? Text.MarkdownText : Text.PlainText
                    wrapMode: Text.Wrap
                    font { family: p.theme.mono; pixelSize: p.theme.px(13) }
                    color: p.theme.text
                    linkColor: p.theme.goldHi
                    onLinkActivated: link => { if (/^https?:\/\//.test(link)) Quickshell.execDetached(["xdg-open", link]); }
                }
            }
        }
    }
    Text {
        visible: !p.off && (Zeus.notice !== "" || (Zeus.lastError !== null && Date.now() / 1000 - Zeus.lastError.at < 600))
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        text: Zeus.notice || (Zeus.lastError ? Zeus.lastError.text : "")
        wrapMode: Text.Wrap
        font { family: p.theme.mono; pixelSize: p.theme.px(12) }
        color: Zeus.lastError && !Zeus.notice ? p.theme.red : p.theme.muted
    }

    // ── waiting for your yes: after the conversation it belongs to, right above the field
    Column {
        id: approvalsBox
        visible: p.waiting && !p.off
        width: p.panelWidth - 2
        topPadding: p.theme.px(12)
        bottomPadding: p.theme.px(12)
        property Item noButton: null
        Repeater {
            model: Zeus.approvals
            delegate: Column {
                id: card
                required property var modelData
                required property int index
                width: p.panelWidth - 2
                spacing: p.theme.px(4)
                PanelLine { theme: p.theme; heading: true; label: p.t("zeus.approval.heading", "Zeus wants to") }
                Text {
                    x: p.theme.px(18); width: parent.width - 2 * x
                    text: (card.modelData.danger ? "⚠ " : "") + (p.sentence(card.modelData.reason) || card.modelData.tool)
                    wrapMode: Text.Wrap
                    font { family: p.theme.mono; pixelSize: p.theme.px(13); bold: true }
                    color: card.modelData.danger ? p.theme.red : p.theme.text
                }
                Text {
                    visible: !!card.modelData.preview
                    x: p.theme.px(18); width: parent.width - 2 * x
                    text: card.modelData.preview || ""
                    maximumLineCount: 8
                    elide: Text.ElideRight
                    wrapMode: Text.WrapAnywhere
                    font { family: p.theme.mono; pixelSize: p.theme.px(12) }
                    color: p.theme.muted
                }
                PanelAction {
                    id: yes
                    theme: p.theme; icon: ""; label: p.t("zeus.approval.yes", "Yes, do it")
                    hint: activeFocus ? "⏎" : ""
                    onActivated: Zeus.approve(card.modelData.id)
                }
                PanelAction {
                    theme: p.theme; visible: !card.modelData.danger; icon: ""
                    label: p.t("zeus.approval.always", "Yes, and don't ask again in this chat")
                    hint: activeFocus ? "⏎" : ""
                    onActivated: Zeus.always(card.modelData.id)
                }
                PanelAction {
                    theme: p.theme; icon: ""; danger: true; label: p.t("zeus.approval.no", "No")
                    hint: activeFocus ? "⏎" : ""
                    onActivated: Zeus.deny(card.modelData.id)
                    Component.onCompleted: if (card.index === 0) approvalsBox.noButton = this
                }
            }
        }
    }

    // ── the field: Enter sends (not while something waits for your yes), Esc closes the panel
    Item {
        visible: !p.off
        width: p.panelWidth - 2
        height: p.theme.px(44)
        Rectangle {
            anchors { fill: parent; leftMargin: p.theme.px(12); rightMargin: p.theme.px(12); topMargin: p.theme.px(4); bottomMargin: p.theme.px(4) }
            color: p.theme.field
            border.color: ask.activeFocus ? p.theme.gold : p.theme.line
            TextInput {
                id: ask
                anchors { left: parent.left; right: sendHint.left; leftMargin: 10; rightMargin: 8; top: parent.top; bottom: parent.bottom }
                verticalAlignment: TextInput.AlignVCenter
                activeFocusOnTab: true
                enabled: Zeus.connected
                font { family: p.theme.mono; pixelSize: p.theme.px(14) }
                color: p.theme.text
                selectionColor: p.theme.gold
                clip: true
                function submit() { if (p.waiting || !text.trim()) return; Zeus.send(text); text = ""; }
                Keys.onReturnPressed: submit()
                Keys.onEnterPressed: submit()
                Text {
                    visible: !ask.text
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    elide: Text.ElideRight
                    text: p.waiting ? p.t("zeus.ask.waiting", "Answer Zeus above first (↑)")
                        : Zeus.state === "thinking" ? p.t("zeus.ask.thinking", "Zeus is thinking …")
                        : p.t("zeus.ask", "Ask Zeus …")
                    font: ask.font
                    color: p.theme.muted
                }
            }
            Text {
                id: sendHint
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: ask.text && !p.waiting ? p.t("zeus.ask.send", "⏎ send") : ""
                font { family: p.theme.mono; pixelSize: p.theme.px(12) }
                color: p.theme.muted
            }
        }
    }
    PanelAction { theme: p.theme; visible: !p.off && Zeus.state === "thinking"; icon: ""; danger: true; label: p.t("zeus.stop", "Stop"); onActivated: Zeus.interrupt() }
    PanelAction { theme: p.theme; visible: !p.off && Zeus.messages.length > 0 && Zeus.state !== "thinking" && !p.waiting; icon: ""; label: p.t("zeus.new", "New chat"); onActivated: Zeus.newChat() }

    // ── what the last answer changed
    Repeater {
        model: p.off ? [] : Zeus.undoable.slice(0, 1)
        delegate: PanelAction {
            required property var modelData
            theme: p.theme; icon: ""
            label: p.t("zeus.undo", "Undo") + ": " + modelData.text
            onActivated: Zeus.undo()
        }
    }

    // ── which model answers: local / free / subscription
    PanelLine { theme: p.theme; heading: true; label: p.t("zeus.model.heading", "Model") }
    PanelAction {
        theme: p.theme; icon: p.showModels ? "" : ""
        label: (p.modelLabel || p.t("zeus.model.none", "No model yet")).replace(/ · lokal$/, "")
        hint: Zeus.cloud ? Zeus.provider : p.t("zeus.model.local", "on this PC")
        onActivated: p.showModels = !p.showModels
    }
    // the fallback chain (Olympus' general.fallback): who answers when this one hits its free quota or is down
    PanelLine {
        theme: p.theme
        visible: !p.showModels && Zeus.cloud && p.chain.length > 0   // a local model has no fallback
        label: p.t("zeus.fallback", "If it does not answer")
        value: p.chain.join("  →  ")
    }
    readonly property var chain: (Zeus.models.fallback || []).filter(f => f.available && f.id !== Zeus.model)
        .map(f => f.cloud ? f.label : p.t("zeus.model.group.local", "Local"))
    readonly property string modelLabel: {
        const c = (Zeus.models.choices || []).find(x => x.id === Zeus.model);
        return c ? c.label : Zeus.model;
    }
    Repeater {
        model: p.showModels ? p.groups : []
        delegate: Column {
            required property var modelData
            width: p.panelWidth - 2
            PanelLine { theme: p.theme; sub: true; label: modelData.label }
            Repeater {
                model: modelData.items
                delegate: PanelAction {
                    required property var modelData
                    theme: p.theme
                    icon: modelData.id === Zeus.model ? "" : ""
                    label: modelData.label.replace(/^[^:]*: /, "").replace(/ · lokal$/, "")
                    hint: modelData.provider === "lokal" ? (modelData.size || "") : modelData.provider
                    onActivated: { Zeus.setModel(modelData.id); p.showModels = false; }
                }
            }
        }
    }
    Text {
        visible: Zeus.modelError !== ""
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        text: Zeus.modelError
        wrapMode: Text.Wrap
        font { family: p.theme.mono; pixelSize: p.theme.px(12) }
        color: p.theme.red
    }
    readonly property var groups: {
        const all = Zeus.models.choices || [];
        const kind = c => !c.cloud ? "local" : /abonnement|subscription/i.test(c.cost || "") ? "sub" : /gratis|free/i.test(c.cost || "") ? "free" : "other";
        return [["local", t("zeus.model.group.local", "Local")], ["free", t("zeus.model.group.free", "Free")],
                ["sub", t("zeus.model.group.sub", "Subscription")], ["other", t("zeus.model.group.other", "Other")]]
            .map(g => ({ label: g[1], items: all.filter(c => kind(c) === g[0]) })).filter(g => g.items.length);
    }

    PanelAction {
        theme: p.theme
        visible: Zeus.connected && !p.off
        icon: ""
        label: p.t("zeus.off", "Turn Zeus off")
        hint: p.t("zeus.off.hint", "frees the graphics card")
        onActivated: Zeus.setAi(false)
    }
}
