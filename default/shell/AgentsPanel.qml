// The Agents panel (B4): the background tasks of every AI agent (Claude Code, Codex, OpenCode, Aider, Hermes,
// OpenClaw …), grouped per agent: the folder, what it is doing (working, waiting for you, done, error) and its
// last line, with Open / Log / Stop / Remove. «New task» picks an agent, a folder and the task, and starts it
// through olymparch-agent (the agent's own background mode, or a tmux session per task). Data: Agents.qml.
import QtQuick
import Quickshell

Dropdown {
    id: p
    name: "agents"
    icon: ""
    title: t("agents.title", "Agents")
    en: "Agents"
    nb: "Agenter"
    hotkeySetting: "keys.agents"
    panelWidth: theme.px(520)
    function t(key, en) { return I18n.t(key, en); }

    readonly property var installed: Agents.list.filter(a => a.installed)
    readonly property var groups: {
        const by = {};
        for (const tk of Agents.tasks) (by[tk.agent] = by[tk.agent] || []).push(tk);
        return Object.keys(by).sort().map(id => ({ agent: Agents.list.find(a => a.id === id) || { id: id, name: id }, tasks: by[id] }));
    }
    readonly property var words: ({
        working: t("agents.status.working", "working"), waiting: t("agents.status.waiting", "waiting for you"),
        done: t("agents.status.done", "done"), error: t("agents.status.error", "error"), stopped: t("agents.status.stopped", "stopped")
    })
    status: !Agents.available ? t("agents.status.none", "olymparch-agent is not installed")
          : Agents.tasks.length === 0 ? t("agents.status.empty", "No tasks. Start one below.")
          : Agents.waiting ? t("agents.status.someone_waits", "An agent is waiting for you")
          : Agents.active ? t("agents.status.active", "%1 working").replace("%1", Agents.active)
          : t("agents.status.idle", "Nothing running")
    statusTint: Agents.waiting ? theme.goldHi : theme.muted
    initialFocus: newTask

    // ── the tasks, per agent
    Repeater {
        model: p.groups
        delegate: Column {
            id: grp
            required property var modelData
            width: p.panelWidth - 2
            PanelLine { theme: p.theme; heading: true; label: grp.modelData.agent.name }
            Repeater {
                model: grp.modelData.tasks
                delegate: Column {
                    id: task
                    required property var modelData
                    readonly property var tk: modelData
                    readonly property bool running: tk.status === "working" || tk.status === "waiting"
                    width: p.panelWidth - 2
                    spacing: 2
                    bottomPadding: p.theme.px(6)
                    Item {
                        width: parent.width
                        height: p.theme.px(22)
                        Text {
                            x: p.theme.px(18)
                            width: parent.width - 2 * x - stateText.width - 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: (task.tk.dir || "").replace(Quickshell.env("HOME"), "~") + "  ·  " + (task.tk.prompt || "")
                            elide: Text.ElideRight
                            font { family: p.theme.mono; pixelSize: p.theme.px(13) }
                            color: p.theme.text
                        }
                        Text {
                            id: stateText
                            anchors { right: parent.right; rightMargin: p.theme.px(18); verticalCenter: parent.verticalCenter }
                            text: (task.tk.status === "waiting" ? "● " : "") + (p.words[task.tk.status] || task.tk.status)
                            font { family: p.theme.mono; pixelSize: p.theme.px(12) }
                            color: task.tk.status === "waiting" ? p.theme.goldHi : task.tk.status === "error" ? p.theme.red : p.theme.muted
                        }
                    }
                    Text {
                        visible: !!task.tk.last
                        x: p.theme.px(18); width: parent.width - 2 * x
                        text: task.tk.last || ""
                        elide: Text.ElideRight
                        font { family: p.theme.mono; pixelSize: p.theme.px(12) }
                        color: p.theme.muted
                    }
                    Row {
                        x: p.theme.px(18)
                        spacing: p.theme.px(16)
                        Repeater {
                            model: [
                                { id: "open", text: p.t("agents.open", "Open") },
                                { id: "logs", text: p.t("agents.logs", "Log") },
                                task.running ? { id: "stop", text: p.t("agents.stop", "Stop"), danger: true } : { id: "rm", text: p.t("agents.remove", "Remove") }
                            ]
                            delegate: Text {
                                id: act
                                required property var modelData
                                text: modelData.text
                                activeFocusOnTab: true
                                font { family: p.theme.mono; pixelSize: p.theme.px(12); underline: m.containsMouse || activeFocus }
                                color: modelData.danger ? p.theme.red : m.containsMouse || activeFocus ? p.theme.goldHi : p.theme.gold
                                function go() {
                                    const id = task.tk.id;
                                    if (modelData.id === "open") { Agents.open(id); Panels.close("agents"); }
                                    else if (modelData.id === "logs") { Agents.logs(id); Panels.close("agents"); }
                                    else if (modelData.id === "stop") Agents.stop(id);
                                    else Agents.remove(id);
                                }
                                Keys.onReturnPressed: go()
                                Keys.onSpacePressed: go()
                                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: act.go() }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── a new task: the agent, the folder, what to do
    PanelLine { theme: p.theme; heading: true; label: p.t("agents.new.heading", "New task") }
    property string pick: ""
    onOpened: { if (!pick && installed.length) pick = installed[0].id; Agents.refresh(); }
    Text {
        visible: Agents.available && p.installed.length === 0
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        text: p.t("agents.none_installed", "No agent is installed yet: Settings → AI: services and agents.")
        wrapMode: Text.Wrap
        font { family: p.theme.mono; pixelSize: p.theme.px(12) }
        color: p.theme.muted
    }
    Flow {   // the agents that are installed: one is chosen
        visible: p.installed.length > 0
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        spacing: p.theme.px(14)
        Repeater {
            model: p.installed
            delegate: Text {
                id: ag
                required property var modelData
                text: (p.pick === modelData.id ? "● " : "○ ") + modelData.name + (modelData.login === false ? "  (" + p.t("agents.not_signed_in", "not signed in") + ")" : "")
                activeFocusOnTab: true
                font { family: p.theme.mono; pixelSize: p.theme.px(13); bold: p.pick === modelData.id }
                color: p.pick === modelData.id ? p.theme.goldHi : agm.containsMouse || activeFocus ? p.theme.text : p.theme.muted
                Keys.onReturnPressed: p.pick = modelData.id
                Keys.onSpacePressed: p.pick = modelData.id
                MouseArea { id: agm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.pick = ag.modelData.id }
            }
        }
    }
    component Field: Item {
        id: f
        property alias text: input.text
        property string hint: ""
        property alias input: input
        signal accepted
        width: p.panelWidth - 2
        height: p.theme.px(40)
        Rectangle {
            anchors { fill: parent; leftMargin: p.theme.px(12); rightMargin: p.theme.px(12); topMargin: p.theme.px(4); bottomMargin: p.theme.px(4) }
            color: p.theme.field
            border.color: input.activeFocus ? p.theme.gold : p.theme.line
            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                verticalAlignment: TextInput.AlignVCenter
                activeFocusOnTab: true
                font { family: p.theme.mono; pixelSize: p.theme.px(13) }
                color: p.theme.text
                selectionColor: p.theme.gold
                clip: true
                Keys.onReturnPressed: f.accepted()
                Keys.onEnterPressed: f.accepted()
                Text { visible: !input.text; anchors.verticalCenter: parent.verticalCenter; text: f.hint; font: input.font; color: p.theme.muted }
            }
        }
    }
    Field {
        id: folder
        visible: p.installed.length > 0
        hint: p.t("agents.new.folder", "Folder, such as ~/dev/project")
        onAccepted: newTask.input.forceActiveFocus()
    }
    Field {
        id: newTask
        visible: p.installed.length > 0
        hint: p.t("agents.new.task", "What should it do? Enter starts it")
        onAccepted: p.start()
    }
    Text {
        id: startError
        visible: text !== ""
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        wrapMode: Text.Wrap
        font { family: p.theme.mono; pixelSize: p.theme.px(12) }
        color: p.theme.red
    }
    function start() {
        const dir = folder.text.trim() || "~";
        const what = newTask.text.trim();
        if (!pick || !what) { startError.text = t("agents.new.missing", "Pick an agent and write the task."); return; }
        if (!/^(~|\/)/.test(dir)) { startError.text = t("agents.new.path", "The folder must start with ~ or /."); return; }
        startError.text = "";
        Agents.run(["new", pick, dir, what]);
        newTask.text = "";
    }
}
