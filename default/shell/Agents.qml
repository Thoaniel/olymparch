pragma Singleton
// The AI agents' tasks for the bar and the Agents panel: $XDG_RUNTIME_DIR/olymparch/agents.json, written by
// olymparch-agent (and by the agents' own hooks through it). The shell only reads it and runs olymparch-agent.
//   { "agents": [{ id, name, icon, installed, login, native }],
//     "tasks":  [{ id, agent, dir, prompt, status: working|waiting|done|error|stopped, started, updated, last }] }
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: agents
    readonly property string file: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/olymparch/agents.json"
    readonly property var data: {
        const t = view.text();
        if (!t || !t.trim()) return { agents: [], tasks: [] };
        try { const d = JSON.parse(t) || {}; return { agents: d.agents || [], tasks: d.tasks || [] }; } catch (e) { return { agents: [], tasks: [] }; }
    }
    readonly property var tasks: data.tasks
    readonly property var list: data.agents
    readonly property int active: tasks.filter(t => t.status === "working" || t.status === "waiting").length
    readonly property bool waiting: tasks.some(t => t.status === "waiting")
    readonly property bool present: Quickshell.env("OLYMPARCH_AGENTS_HIDE") !== "1"   // tests
    property bool available: false        // olymparch-agent is installed

    FileView {
        id: view
        path: agents.file
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: reload()
    }
    Process {
        command: ["sh", "-c", "command -v olymparch-agent"]
        running: true
        onExited: code => agents.available = code === 0
    }
    // a notification when a task starts waiting for you, or ends (done / error); the notification daemon's own
    // rules apply (do not disturb, games). Nothing is said for what was already so when the shell started.
    property var seen: null
    onTasksChanged: {
        const now = {};
        for (const t of tasks) now[t.id] = t.status;
        if (seen !== null) {
            for (const t of tasks) {
                if (seen[t.id] === t.status || !["waiting", "done", "error"].includes(t.status)) continue;
                const a = list.find(x => x.id === t.agent);
                const who = a ? a.name : t.agent;
                const title = t.status === "waiting" ? I18n.t("agents.notify.waiting", "%1 is waiting for you").replace("%1", who)
                            : t.status === "done" ? I18n.t("agents.notify.done", "%1 is done").replace("%1", who)
                            : I18n.t("agents.notify.error", "%1 stopped with an error").replace("%1", who);
                const body = String(t.dir || "").replace(Quickshell.env("HOME"), "~") + (t.last ? "\n" + t.last : "");
                Quickshell.execDetached(["notify-send", "-a", "Olymparch", "-u", t.status === "waiting" ? "normal" : "low", title, body]);
            }
        }
        seen = now;
    }
    function run(args) { Quickshell.execDetached(["olymparch-agent"].concat(args)); }
    function open(id) { run(["open", id]); }
    function logs(id) { run(["logs", id]); }
    function stop(id) { run(["stop", id]); }
    function remove(id) { run(["rm", id]); }
    function refresh() { run(["list", "--write"]); }
}
