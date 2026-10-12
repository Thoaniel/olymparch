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
    property var schema: ({ groups: [], pages: [], settings: [] })
    property var defaults: ({})
    property var values: ({})

    FileView {
        path: "/usr/share/olymparch/settings/schema.json"
        blockLoading: true
        onLoaded: {
            try {
                const s = JSON.parse(text());
                const d = {};
                for (const e of s.settings) d[e.key] = e.default;
                settings.defaults = d;
                settings.schema = s;
            } catch (e) {
                console.warn("settings: bad schema:", e);
            }
        }
    }

    FileView {
        id: user
        path: settings.file
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { settings.values = JSON.parse(text()) || {}; } catch (e) { console.warn("settings:", settings.file, e); }
        }
        onLoadFailed: settings.values = {}
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
        p.done.connect((out, code) => {
            user.reload();
            if (onDone) onDone(out, code);
            p.destroy();
        });
        p.running = true;
    }
    function set(key, value, onDone) { run(["set", key, String(value)], onDone); }
    function reset(key, onDone) { run(["reset", key], onDone); }

    Component {
        id: runner
        Process {
            signal done(string out, int code)
            stdout: StdioCollector { id: out }
            onExited: code => done(out.text, code)
        }
    }
}
