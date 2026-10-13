pragma Singleton
// Zeus in the shell: one long-lived `olympus bar` (Olympus' JSON-line bridge, docs/bar.md in Olympus) while
// Olympus is installed and Settings → Zeus is on. It holds what the bar item and the Zeus panel show (status,
// the conversation, approvals, models) and sends what you do back. The server always runs in the background
// (a systemd --user service); the shell never starts it and never opens a terminal for it.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: zeus
    // OLYMPARCH_OLYMPUS: another olympus (the VM tests' stub, tests/vm/olympus-stub)
    readonly property string bin: Quickshell.env("OLYMPARCH_OLYMPUS") || Quickshell.env("HOME") + "/.local/bin/olympus"
    property bool installed: false
    readonly property bool enabled: installed && Settings.get("zeus.enabled") !== false

    // ── status (the bridge's {"type":"bar"} line)
    property bool connected: false
    property var ai: null                 // true / false / null (unknown)
    property string model: ""
    property string provider: ""
    property bool cloud: false
    property string answering: ""         // the model that answered last
    property string state: "idle"         // off | approval | thinking | idle
    property var approvals: []            // [{ id, tool, reason, danger, preview }]
    property var lastError: null          // { text, at }
    // ── the conversation: [{ kind: "user"|"agent", text, model, tools: [{ id, name, detail, ok, summary }], rejected }]
    property var messages: []
    property string notice: ""
    property var undoable: []             // [{ seq, text }] newest first: what the last turns changed
    // ── models: GET /api/v1/models
    property var models: ({ current: "", choices: [] })
    property string modelError: ""

    Process {
        id: check
        command: ["test", "-x", zeus.bin]
        running: true
        onExited: code => zeus.installed = code === 0
    }
    Process {
        id: bridge
        command: [zeus.bin, "bar"]
        running: zeus.enabled
        stdinEnabled: true
        stdout: SplitParser { onRead: line => zeus.receive(line) }
        stderr: SplitParser { onRead: _ => {} }
        onExited: { zeus.connected = false; if (zeus.enabled) restart.start(); }
    }
    Timer { id: restart; interval: 3000; onTriggered: if (zeus.enabled && !bridge.running) bridge.running = true }

    function out(obj) { if (bridge.running) bridge.write(JSON.stringify(obj) + "\n"); }
    property int rid: 0
    property var pending: ({})            // rid → callback(reply)
    function http(method, path, body, done) {
        rid += 1;
        if (done) pending[rid] = done;
        out({ type: "http", rid: rid, method: method, path: path, body: body || {} });
    }
    function cmd(name, args, done) {
        rid += 1;
        if (done) pending[rid] = done;
        out(Object.assign({ cmd: name, rid: rid }, args || {}));
    }

    // ── what you do
    function send(text) { const t = String(text || "").trim(); if (t) out({ type: "send", text: t }); }
    function approve(id) { cmd("approve", { id: id }); }
    function deny(id) { cmd("deny", { id: id }); }
    function always(id) { cmd("always", { id: id }); }
    function interrupt() { out({ type: "interrupt" }); }
    function newChat() { out({ type: "new" }); }
    function setAi(on) { cmd("ai", { on: on }); }
    function setModel(id, done) { cmd("model", { id: id }, r => { modelError = r.ok ? "" : (r.error || ""); loadModels(); if (done) done(r); }); }
    function undo() { cmd("undo", {}, r => { if (r.ok) undoable = undoable.slice(1); }); }
    function loadModels() {
        http("GET", "/api/v1/models", null, r => { if (r.status === 200 && r.json) models = r.json; });
    }
    function warm() { http("POST", "/api/v1/zeus/warm", {}, null); }

    // ── what comes back
    function receive(line) {
        let m;
        try { m = JSON.parse(line); } catch (e) { return; }
        if (!m || typeof m !== "object") return;
        if (m.rid !== undefined && m.rid !== null && pending[m.rid]) {
            const f = pending[m.rid];
            delete pending[m.rid];
            f(m);
            return;
        }
        switch (m.type) {
        case "bar":
            connected = !!m.connected; ai = m.ai; model = m.model || ""; provider = m.provider || "";
            cloud = !!m.cloud; answering = m.answering || ""; state = m.state || "idle";
            approvals = m.approvals || []; lastError = m.last_error || null;
            break;
        case "bridge":
            if (m.status === "connected") loadModels();
            break;
        case "history":
            messages = (m.items || []).map(i => ({ kind: i.kind, text: i.text || "", model: i.model || "",
                                                  tools: (i.tools || []).map(t => typeof t === "string" ? { name: t } : t),
                                                  rejected: !!i.rejected }));
            break;
        case "user":
            push({ kind: "user", text: m.text || "" });
            notice = "";
            break;
        case "agent_start":
            push({ kind: "agent", text: "", model: m.model || "", tools: [] });
            break;
        case "chunk":
            editLast(a => a.kind === "agent", a => a.text += m.text || "");
            break;
        case "tool":
            editLast(a => a.kind === "agent", a => a.tools = a.tools.concat([{ id: m.id, name: m.name, detail: m.detail || "" }]));
            break;
        case "tool_result":
            editLast(a => a.kind === "agent", a => a.tools = a.tools.map(t => t.id === m.id ? Object.assign({}, t, { ok: m.ok, summary: m.summary, denied: m.denied }) : t));
            break;
        case "judge_rejected":
            editLast(a => a.kind === "agent", a => { a.text = ""; a.rejected = true; });
            break;
        case "undoable":
            undoable = [{ seq: m.seq, text: m.text || "" }].concat(undoable).slice(0, 5);
            break;
        case "notice":
            notice = m.text || "";
            break;
        case "error":
            notice = m.text || "";
            break;
        case "cleared":
            messages = []; notice = ""; undoable = [];
            break;
        case "model":
            model = m.model || model; cloud = !!m.cloud; provider = m.provider || provider;
            loadModels();
            break;
        }
    }
    function push(msg) { messages = messages.concat([msg]).slice(-60); }
    function editLast(match, change) {
        const list = messages.slice();
        for (let i = list.length - 1; i >= 0; i--) {
            if (match(list[i])) { const c = Object.assign({}, list[i]); change(c); list[i] = c; messages = list; return; }
        }
    }
}
