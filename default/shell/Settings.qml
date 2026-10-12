pragma Singleton
// Olymparch settings for the shell: the schema (/usr/share/olymparch/settings/schema.json: what exists and the
// defaults) and your values (~/.config/olymparch/settings.json), re-read whenever the file changes. Changes go
// through olymparch-settings, the same command you and Zeus use, so there is no second copy of anything.
//   visible: Settings.get("appearance.bar")
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: settings
    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/olymparch/settings.json"
    // read synchronously at start (blockLoading), so the first bindings already see the defaults
    readonly property var schema: {
        try { return JSON.parse(schemaFile.text()); } catch (e) { console.warn("settings: bad schema:", e); }
        return { groups: [], pages: [], settings: [] };
    }
    readonly property var defaults: {
        const d = {};
        for (const e of schema.settings) d[e.key] = e.default;
        return d;
    }
    readonly property var values: {
        const t = user.text();
        if (!t || !t.trim()) return {};
        try { return JSON.parse(t) || {}; } catch (e) { console.warn("settings:", file, e); return {}; }
    }

    FileView {
        id: schemaFile
        path: "/usr/share/olymparch/settings/schema.json"
        blockLoading: true
    }
    FileView {
        id: user
        path: settings.file
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    function reload() { user.reload(); }

    // KEY or KEY@OUTPUT; falls back to the schema default
    function get(key) {
        const v = values[key];
        return v !== undefined ? v : defaults[key.split("@")[0]];
    }
    function entry(key) { return schema.settings.find(e => e.key === key.split("@")[0]); }

    // olymparch-settings ARGS…; onDone(stdout, exitCode) when it finishes, then settings.json is read again
    function run(args, onDone) {
        const p = runner.createObject(settings, { command: ["olymparch-settings"].concat(args) });
        p.done.connect((out, code, err) => {
            user.reload();
            if (onDone) onDone(out, code, err);
            p.destroy();
        });
        p.running = true;
    }
    function set(key, value, onDone) { run(["set", key, String(value)], onDone); }
    function reset(key, onDone) { run(["reset", key], onDone); }

    Component {
        id: runner
        Process {
            signal done(string out, int code, string err)
            stdout: StdioCollector { id: out }
            stderr: StdioCollector { id: err }
            onExited: code => done(out.text, code, err.text)
        }
    }
}
