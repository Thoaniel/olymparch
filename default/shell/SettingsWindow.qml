// Settings (Super+comma, «Settings» in the menu, or `olymparch-settings open`). Every page and row is drawn from
// the schema; every change runs olymparch-settings, so the window is just a face on the same files and commands.
// Keys: type to search everything, ↑/↓ change page, Tab walks the controls, ←/→ change a choice, Space toggles,
// Ctrl+F searches again, Esc closes. Risky changes (resolution, scale …) ask «Keep?» on every monitor and go
// back by themselves after 15 s.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Scope {
    id: win
    required property var theme
    property bool open: false
    property string page: "display"
    property string query: ""
    readonly property bool advanced: Settings.get("settings.advanced") === true
    readonly property string lang: I18n.lang
    readonly property color dim: "#6e6a78"
    property var monitors: []            // hyprctl monitors -j
    property string monitor: ""          // the output the display page shows
    property var about: ({})             // olymparch-settings about
    property string outputKey: ""        // the last action with output (doctor …) and what it printed
    property string output: ""
    property bool outputError: false     // output is why a change was refused
    // ── what this machine has, asked on open: settings it can't use (hidden), choices (default apps,
    //    terminals) and lists (Wi-Fi, Bluetooth). Keyed by setting.
    property var missing: []
    property var choices: ({})           // KEY → [{ value, text }]
    property var items: ({})             // KEY → { lines: [{ id, state, name, detail }], message, busy }
    function loadMissing(then) { Settings.run(["missing"], out => { win.missing = out.split("\n").filter(l => l); if (then) then(); }); }
    function loadChoices(s) {
        Settings.run(["choices", s.key], out => {
            const c = Object.assign({}, win.choices);
            c[s.key] = out.split("\n").filter(l => l).map(l => { const t = l.split("\t"); return { value: t[0], text: t[1] || t[0] }; });
            win.choices = c;
        });
    }
    function setItems(key, patch) {
        const all = Object.assign({}, win.items);
        all[key] = Object.assign({ lines: [], message: "", busy: "" }, all[key] || {}, patch);
        win.items = all;
    }
    function loadItems(key, scan) {
        setItems(key, { busy: scan ? I18n.t("settings.items.searching", "Searching …") : "" });
        Settings.run(["items", key].concat(scan ? ["--scan"] : []), out => {
            const lines = [], msgs = [];
            for (const l of out.split("\n").filter(l => l)) {
                if (l.startsWith("! ")) {   // "! CODE english text": the code picks the translation
                    const m = l.match(/^! (\S+) (.*)$/);
                    msgs.push(m ? I18n.t("settings.items." + m[1], m[2]) : l.slice(2));
                    continue;
                }
                const t = l.split("\t");
                lines.push({ id: t[0], state: t[1], name: t[2] || t[0], detail: t[3] || "" });
            }
            win.setItems(key, { lines: lines, message: msgs.join("\n"), busy: "" });
        });
    }
    function pickItem(key, it, how) {
        // ── a «level» row (audio.per_app): − / + / mute, then the list again with the new volume
        if (it.state === "level") { Settings.run(["pick", key, it.id, how || "mute"], () => win.loadItems(key, false)); return; }
        setItems(key, { busy: (it.state === "on" ? I18n.t("settings.items.disconnecting", "Disconnecting %1 …") : I18n.t("settings.items.connecting", "Connecting %1 …")).arg(it.name) });
        Settings.run(["pick", key, it.id], () => win.loadItems(key, false));
    }
    // the rows on screen need their choices and lists
    function loadFor(rows) {
        for (const s of rows) {
            if ((s.options_from === "desktop" || s.installed) && !choices[s.key]) loadChoices(s);
            if (s.widget === "items" && !items[s.key]) loadItems(s.key, false);
        }
    }
    onRowsChanged: if (open) loadFor(rows)
    property var pending: null           // a --try waiting for «Keep»: { key, value, text, token }
    property int countdown: 0

    function tr(o) { return o ? (o[lang] || o.en || "") : ""; }
    function pageOf(id) { return Settings.schema.pages.find(p => p.id === id); }
    function keyOf(s) { return s.per === "monitor" ? s.key + "@" + monitor : s.key; }
    function valueOf(s) {
        const k = keyOf(s);
        if (pending && pending.key === k) return pending.value;
        const v = Settings.get(k);
        if (s.options_from === "audio.sinks" && !v && !s.options) return Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name : "";
        if (s.options_from === "audio.sources" && !v) return Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.name : "";
        return v;
    }
    function where(s) {
        const a = s.apply || {};
        if (a.command) return "$ " + a.command;
        return (a.file || "") + (a.key && a.key !== s.key ? " · " + a.key : "");
    }
    // [{ value, text }] for a choice, from the schema and, for hardware, from what is plugged in
    function options(s) {
        const out = (s.options || []).map(o => ({ value: o.value, text: tr(o.label) }));
        const m = monitors.find(x => x.name === monitor);
        const modes = m ? m.availableModes.map(x => x.match(/^(\d+x\d+)@([\d.]+)Hz$/)).filter(x => x) : [];
        if (s.options_from === "monitor.resolutions") {
            const seen = new Set();
            for (const x of modes) if (!seen.has(x[1])) { seen.add(x[1]); out.push({ value: x[1], text: x[1].replace("x", " × ") }); }
        } else if (s.options_from === "monitor.rates") {
            const r = valueOf(entryOf("display.resolution"));
            const res = r && r !== "preferred" ? r : (m ? m.width + "x" + m.height : "");
            const seen = new Set();
            for (const x of modes) if (x[1] === res && !seen.has(x[2])) { seen.add(x[2]); out.push({ value: x[2], text: Math.round(parseFloat(x[2])) + " Hz" }); }
        } else if (s.options_from === "monitors") {
            for (const x of monitors) out.push({ value: x.name, text: x.model ? x.model + " (" + x.name + ")" : x.name });
        } else if (s.options_from === "desktop" || s.installed) {   // default apps, terminals: what is installed
            const c = choices[s.key];
            if (c && s.installed) return c;
            for (const x of c || []) if (!out.find(o => o.value === x.value)) out.push(x);
        } else if (s.options_from === "audio.sinks" || s.options_from === "audio.sources") {
            const sink = s.options_from === "audio.sinks";
            for (const n of Pipewire.nodes.values)
                if (n.audio && !n.isStream && n.isSink === sink) out.push({ value: n.name, text: n.description || n.nickname || n.name });
        }
        return out;
    }
    function entryOf(key) { return Settings.schema.settings.find(e => e.key === key); }
    function textOf(s, v) {
        const o = options(s).find(x => x.value === String(v));
        return o ? o.text : String(v);
    }

    // The rows on screen: a page (simple, or all with Advanced view), or every match for the search
    readonly property var rows: {
        const all = Settings.schema.settings.filter(s => s.key !== "settings.advanced");
        const q = query.trim().toLowerCase();
        if (q) return all.filter(s => [s.key, s.label.en, s.label.nb, s.description ? s.description.en : "", s.description ? s.description.nb : "",
                                         tr(pageOf(s.page) ? pageOf(s.page).label : null)].join(" ").toLowerCase().includes(q));
        return all.filter(s => s.page === page && (advanced || s.level === "simple"));
    }
    readonly property var shownRows: rows.filter(s => !missing.includes(s.key))
    readonly property var hiddenAdvanced: query ? [] : Settings.schema.settings.filter(s => s.page === page && s.level === "advanced" && s.key !== "settings.advanced" && !advanced)

    function change(s, value) {
        const key = keyOf(s);
        if (s.risky) {
            Settings.run(["set", key, String(value), "--try", "15"], (out, code) => {
                const m = out.match(/pending (\S+)/);
                if (m) {
                    win.pending = { key: key, value: String(value), text: (tr(s.label) + " " + textOf(s, value)).toUpperCase(), token: m[1] };
                    win.countdown = 15;
                }
                win.refreshMonitors();
            });
        } else {
            Settings.run(["set", key, String(value)], (out, code, err) => {
                if (s.page === "display") win.refreshMonitors();
                // a refused value (a shortcut that is taken …): say why under the row
                if (code) { win.outputKey = s.key; win.output = err.replace(/^olymparch-settings: /gm, "").trim(); win.outputError = true; }
                else if (win.outputError && win.outputKey === s.key) win.outputKey = "";
            });
        }
    }
    function keep() { if (pending) Settings.run(["keep"], () => answered()); }
    function revert() { if (pending) Settings.run(["revert"], () => answered()); }
    // A new mode or scale changes the monitor's logical size; the window is shown again so Hyprland sizes it anew
    function answered() {
        pending = null;
        refreshMonitors();
        if (open) { open = false; reopen.start(); }
    }
    Timer { id: reopen; interval: 200; onTriggered: win.open = true }
    function act(s) {
        if (s.unless) { win.outputKey = s.key; win.output = I18n.t("settings.install.busy", "Installing … (this can take a minute)"); win.outputError = false; }
        Settings.run(["run", s.key], (out, code) => {
            if (s.output) { win.outputKey = s.key; win.output = out.trim(); win.outputError = false; }
            // ── an «Install …» row (unless): once installed it goes and the setting it was for shows
            if (s.unless) {
                if (code) { win.outputKey = s.key; win.output = I18n.t("settings.install.failed", "Not installed: see /var/log/olymparch-install-app.log"); win.outputError = true; }
                win.loadMissing(() => search.forceActiveFocus());   // the row (and its focus) is gone: keys go to search again
            }
        });
    }
    function resetPage() {
        for (const s of Settings.schema.settings.filter(s => s.page === page && s.type !== "action" && !s.readonly)) {
            const k = keyOf(s);
            if (Settings.values[k] !== undefined) Settings.reset(k, () => win.refreshMonitors());
        }
    }
    function step(d) {
        const ids = Settings.schema.pages.map(p => p.id);
        page = ids[(ids.indexOf(page) + d + ids.length) % ids.length];
        query = "";
        outputKey = "";
    }

    Process {
        id: monProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.monitors = JSON.parse(text); } catch (e) { win.monitors = []; }
                if (!win.monitors.find(m => m.name === win.monitor)) {
                    const m = win.monitors.find(m => m.focused) || win.monitors[0];
                    win.monitor = m ? m.name : "";
                }
            }
        }
    }
    function refreshMonitors() { monProc.running = true; }
    Process {
        id: aboutProc
        command: ["olymparch-settings", "about"]
        stdout: StdioCollector {
            onStreamFinished: {
                const a = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) a[l.slice(0, i)] = l.slice(i + 1); }
                win.about = a;
            }
        }
    }

    GlobalShortcut {
        appid: "olymparch"
        name: "settings"
        description: "Open Olymparch Settings"
        onPressed: win.open = !win.open
    }
    IpcHandler {
        target: "settings"
        function open(): void { win.open = true; }
        function close(): void { win.open = false; }
        function toggle(): void { win.open = !win.open; }
        function page(id: string): void { win.step(0); win.page = id; win.open = true; }  // not "show": qs ipc has a subcommand by that name
        function reload(): void { Settings.reload(); }
    }
    onOpenChanged: if (open) { refreshMonitors(); aboutProc.running = true; choices = {}; items = {}; loadMissing(); loadFor(rows); }

    Timer {
        running: win.pending !== null
        interval: 1000
        repeat: true
        onTriggered: if (win.countdown > 0 && --win.countdown === 0) win.revert()
    }

    FloatingWindow {
        id: window
        title: "Olymparch Settings"
        visible: win.open
        implicitWidth: 1040
        implicitHeight: 680
        color: win.theme.surface
        onVisibleChanged: {
            if (!visible) win.open = false;
            else Qt.callLater(() => search.forceActiveFocus());
        }

        Item {
            id: body
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier)) { search.forceActiveFocus(); search.selectAll(); e.accepted = true; }
                else if (e.key === Qt.Key_PageDown && (e.modifiers & Qt.ControlModifier)) { win.step(1); e.accepted = true; }
                else if (e.key === Qt.Key_PageUp && (e.modifiers & Qt.ControlModifier)) { win.step(-1); e.accepted = true; }
                else if (e.key === Qt.Key_Escape) {
                    if (win.query) { win.query = ""; search.forceActiveFocus(); } else win.open = false;
                    e.accepted = true;
                }
            }

            // gold corner marks: this is the focused panel
            Rectangle { x: 0; y: 0; width: 14; height: 2; color: win.theme.gold; z: 5 }
            Rectangle { x: 0; y: 0; width: 2; height: 14; color: win.theme.gold; z: 5 }
            Rectangle { x: parent.width - 14; y: parent.height - 2; width: 14; height: 2; color: win.theme.gold; z: 5 }
            Rectangle { x: parent.width - 2; y: parent.height - 14; width: 2; height: 14; color: win.theme.gold; z: 5 }

            // ── the sidebar: search and every page, in groups
            Rectangle {
                id: nav
                width: 216
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                color: win.theme.bg
                Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: win.theme.line }

                Rectangle {
                    id: searchBox
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    height: 32
                    color: "#0d0d12"
                    border.color: search.activeFocus ? win.theme.gold : win.theme.line
                    TextInput {
                        id: search
                        anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
                        verticalAlignment: TextInput.AlignVCenter
                        font { family: win.theme.mono; pixelSize: win.theme.px(13) }
                        color: win.theme.text
                        clip: true
                        text: win.query
                        onTextEdited: win.query = text
                        Keys.onDownPressed: win.query ? list.forceActiveFocus() : win.step(1)
                        Keys.onUpPressed: if (!win.query) win.step(-1)
                        Keys.onReturnPressed: list.forceActiveFocus()
                        Text {
                            visible: !search.text
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            elide: Text.ElideMiddle   // at large text sizes: "⌕ Søk i … Ctrl+F" keeps the shortcut
                            text: I18n.t("settings.search", "⌕ Search everything · Ctrl+F")
                            font: search.font
                            color: win.theme.muted
                        }
                    }
                }

                Flickable {
                    id: navFlick
                    anchors { left: parent.left; right: parent.right; top: searchBox.bottom; bottom: parent.bottom; topMargin: 6 }
                    contentHeight: navCol.implicitHeight + 12
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: navCol
                        width: parent.width - 1
                        Repeater {
                            model: Settings.schema.groups
                            delegate: Column {
                                id: grp
                                required property var modelData
                                width: navCol.width
                                Text {
                                    leftPadding: 14; topPadding: 10; bottomPadding: 4
                                    text: win.tr(grp.modelData.label)
                                    font { family: win.theme.mono; pixelSize: win.theme.px(10); letterSpacing: 1.5 }
                                    color: win.theme.muted
                                }
                                Repeater {
                                    model: Settings.schema.pages.filter(p => p.group === grp.modelData.id)
                                    delegate: Rectangle {
                                        id: item
                                        required property var modelData
                                        readonly property bool current: !win.query && win.page === modelData.id
                                        width: grp.width; height: 26
                                        color: current ? win.theme.raised : "transparent"
                                        onCurrentChanged: if (current && navFlick.height > 100) {
                                            const y = mapToItem(navCol, 0, 0).y;
                                            if (y < navFlick.contentY) navFlick.contentY = Math.max(0, y - 30);
                                            else if (y + height > navFlick.contentY + navFlick.height) navFlick.contentY = y + height - navFlick.height + 8;
                                        }
                                        Rectangle { visible: item.current; width: 2; height: parent.height; color: win.theme.gold }
                                        Text {
                                            anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                            text: win.tr(item.modelData.label)
                                            elide: Text.ElideRight
                                            font { family: win.theme.mono; pixelSize: win.theme.px(13); bold: item.current }
                                            color: item.current ? win.theme.goldHi : win.theme.text
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: { win.query = ""; win.outputKey = ""; win.page = item.modelData.id; } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── the page
            Item {
                id: main
                anchors { left: nav.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }

                Item {
                    id: head
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 16 }
                    height: 26
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.query ? I18n.t("settings.results", "Search: %1 (%2)").arg(win.query).arg(win.rows.length)
                                        : (win.pageOf(win.page) ? win.tr(win.pageOf(win.page).label) : "")
                        font { family: win.theme.mono; pixelSize: win.theme.px(15); bold: true }
                        color: win.theme.text
                    }
                    Item {
                        id: advSwitch
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: advRow.implicitWidth; height: 24
                        activeFocusOnTab: true
                        Keys.onSpacePressed: Settings.set("settings.advanced", !win.advanced)
                        Row {
                            id: advRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Text { text: I18n.t("settings.advanced", "Advanced view"); font { family: win.theme.mono; pixelSize: win.theme.px(12) } color: advSwitch.activeFocus ? win.theme.goldHi : win.theme.muted; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: 30; height: 16; color: "#0d0d12"; anchors.verticalCenter: parent.verticalCenter
                                border.color: win.advanced || advSwitch.activeFocus ? win.theme.gold : win.theme.line
                                Rectangle { x: win.advanced ? 16 : 2; y: 2; width: 10; height: 10; color: win.advanced ? win.theme.gold : win.theme.muted }
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: Settings.set("settings.advanced", !win.advanced) }
                    }
                }

                Flickable {
                    id: list
                    anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top; topMargin: 12; bottomMargin: 8 }
                    contentHeight: content.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    activeFocusOnTab: false
                    Keys.onUpPressed: search.forceActiveFocus()
                    onActiveFocusChanged: if (activeFocus) nextItemInFocusChain(true).forceActiveFocus()
                    function show(item) {   // keep the focused control in view
                        const p = item.mapToItem(content, 0, 0);
                        if (p.y < contentY) contentY = Math.max(0, p.y - 8);
                        else if (p.y + item.height > contentY + height) contentY = Math.min(contentHeight - height, p.y + item.height - height + 8);
                    }

                    Column {
                        id: content
                        width: list.width
                        spacing: 0

                        // the monitors as they are placed; click one to set it up
                        Column {
                            width: parent.width
                            visible: !win.query && win.page === "display"
                            spacing: 6
                            Rectangle {
                                id: arrange
                                width: parent.width; height: 150
                                color: "#0d0d12"
                                border.color: win.theme.line
                                readonly property var box: {
                                    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                                    for (const m of win.monitors) {
                                        x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y);
                                        x1 = Math.max(x1, m.x + m.width / m.scale); y1 = Math.max(y1, m.y + m.height / m.scale);
                                    }
                                    const k = win.monitors.length ? Math.min((width - 40) / (x1 - x0), (height - 30) / (y1 - y0)) : 1;
                                    return { x0: x0, y0: y0, k: k, ox: (width - (x1 - x0) * k) / 2, oy: (height - (y1 - y0) * k) / 2 };
                                }
                                Repeater {
                                    model: win.monitors
                                    delegate: Rectangle {
                                        id: mon
                                        required property var modelData
                                        readonly property bool sel: modelData.name === win.monitor
                                        x: arrange.box.ox + (modelData.x - arrange.box.x0) * arrange.box.k
                                        y: arrange.box.oy + (modelData.y - arrange.box.y0) * arrange.box.k
                                        width: modelData.width / modelData.scale * arrange.box.k - 4
                                        height: modelData.height / modelData.scale * arrange.box.k - 4
                                        color: win.theme.raised
                                        border { color: sel ? win.theme.gold : win.theme.line; width: sel ? 2 : 1 }
                                        Column {
                                            anchors.centerIn: parent
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: mon.modelData.model || mon.modelData.name; font { family: win.theme.mono; pixelSize: win.theme.px(13); bold: true } color: mon.sel ? win.theme.goldHi : win.theme.text }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: mon.modelData.name + " · " + mon.modelData.width + "×" + mon.modelData.height; font { family: win.theme.mono; pixelSize: win.theme.px(11) } color: win.theme.muted }
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: win.monitor = mon.modelData.name }
                                    }
                                }
                            }
                            Text { text: I18n.t("settings.monitors.hint", "Click to choose · position is set below"); font { family: win.theme.mono; pixelSize: win.theme.px(11) } color: win.theme.muted }
                            Text {
                                topPadding: 6
                                readonly property var m: win.monitors.find(x => x.name === win.monitor)
                                text: m ? ((m.model || m.description || "") + " · " + m.name).toUpperCase() : ""
                                font { family: win.theme.mono; pixelSize: win.theme.px(11); letterSpacing: 1.5 }
                                color: win.theme.muted
                            }
                        }

                        // version and hardware
                        Column {
                            width: parent.width
                            visible: !win.query && win.page === "about"
                            bottomPadding: 6
                            Text { text: win.about.version || "Olymparch"; font { family: win.theme.mono; pixelSize: win.theme.px(20); bold: true; letterSpacing: 1 } color: win.theme.gold }
                            Text { topPadding: 2; text: (win.about.hyprland ? "Hyprland " + win.about.hyprland + " · " : "") + "Quickshell"; font { family: win.theme.mono; pixelSize: win.theme.px(12) } color: win.theme.muted }
                        }

                        Repeater {
                            model: win.shownRows
                            delegate: Item {
                                id: row
                                required property var modelData
                                readonly property var s: modelData
                                readonly property var value: win.valueOf(s)
                                readonly property bool ready: s.ready === true
                                readonly property string w: s.widget || ({ bool: "switch", choice: "select", number: "slider", text: "field", action: "button" })[s.type]
                                readonly property var opts: s.type === "choice" ? win.options(s) : []
                                width: content.width
                                height: Math.max(info.implicitHeight, ctl.height) + 18 + (out.visible ? out.height + 8 : 0)

                                Column {
                                    id: info
                                    y: 9
                                    width: 300
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        text: (win.query ? win.tr(win.pageOf(row.s.page).label) + " › " : "") + win.tr(row.s.label)
                                        wrapMode: Text.Wrap
                                        font { family: win.theme.mono; pixelSize: win.theme.px(13) }
                                        color: row.ready ? win.theme.text : win.theme.muted
                                    }
                                    Text {
                                        width: parent.width
                                        visible: text.length > 0
                                        text: win.tr(row.s.description)
                                        wrapMode: Text.Wrap
                                        font { family: win.theme.mono; pixelSize: win.theme.px(11) }
                                        color: win.theme.muted
                                    }
                                    Text {
                                        width: parent.width
                                        text: win.where(row.s)
                                        elide: Text.ElideMiddle
                                        font { family: win.theme.mono; pixelSize: win.theme.px(10) }
                                        color: win.dim
                                    }
                                }

                                Item {
                                    id: ctl
                                    x: 316
                                    y: 7
                                    width: row.width - 316
                                    height: Math.max(26, sw.visible ? sw.height : seg.visible ? seg.height : sel.visible ? sel.height
                                                           : sld.visible ? sld.height : fld.visible ? fld.height : btn.visible ? btn.height : kc.visible ? kc.height
                                                           : itm.visible ? itm.implicitHeight : info2.height)
                                    opacity: row.ready ? 1 : 0.45
                                    enabled: row.ready

                                    // switch
                                    Item {
                                        id: sw
                                        visible: row.w === "switch"
                                        width: 90; height: 24
                                        activeFocusOnTab: visible && row.ready
                                        onActiveFocusChanged: if (activeFocus) list.show(row)
                                        function flip() { win.change(row.s, !(row.value === true)); }
                                        Keys.onSpacePressed: flip()
                                        Keys.onReturnPressed: flip()
                                        Rectangle {
                                            id: swBox
                                            width: 30; height: 16; anchors.verticalCenter: parent.verticalCenter
                                            color: "#0d0d12"
                                            border.color: row.value === true || sw.activeFocus ? win.theme.gold : win.theme.line
                                            Rectangle { x: row.value === true ? 16 : 2; y: 2; width: 10; height: 10; color: row.value === true ? win.theme.gold : win.theme.muted }
                                        }
                                        Text {
                                            anchors { left: swBox.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                            text: row.value === true ? I18n.t("settings.on", "On") : I18n.t("settings.off", "Off")
                                            font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: sw.activeFocus }
                                            color: sw.activeFocus ? win.theme.goldHi : win.theme.text
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: sw.flip() }
                                    }

                                    // segmented choice
                                    Rectangle {
                                        id: seg
                                        visible: row.w === "segmented"
                                        width: segRow.width + 2; height: 26
                                        color: "transparent"
                                        border.color: activeFocus ? win.theme.gold : win.theme.line
                                        activeFocusOnTab: visible && row.ready
                                        onActiveFocusChanged: if (activeFocus) list.show(row)
                                        function pick(d) {
                                            const i = row.opts.findIndex(o => o.value === String(row.value));
                                            const n = Math.max(0, Math.min(row.opts.length - 1, i + d));
                                            if (n !== i) win.change(row.s, row.opts[n].value);
                                        }
                                        Keys.onLeftPressed: pick(-1)
                                        Keys.onRightPressed: pick(1)
                                        Row {
                                            id: segRow
                                            x: 1; y: 1
                                            Repeater {
                                                model: row.opts
                                                delegate: Rectangle {
                                                    id: segItem
                                                    required property var modelData
                                                    required property int index
                                                    readonly property bool on: String(row.value) === modelData.value
                                                    width: segText.implicitWidth + 20; height: 24
                                                    color: on ? win.theme.gold : "transparent"
                                                    Rectangle { visible: segItem.index > 0; width: 1; height: parent.height; color: win.theme.line }
                                                    Text {
                                                        id: segText
                                                        anchors.centerIn: parent
                                                        text: segItem.modelData.text
                                                        font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: segItem.on }
                                                        color: segItem.on ? "#0a0a0e" : win.theme.text
                                                    }
                                                    MouseArea { anchors.fill: parent; onClicked: if (!segItem.on) win.change(row.s, segItem.modelData.value) }
                                                }
                                            }
                                        }
                                    }

                                    // select: a box that opens a list in place
                                    Column {
                                        id: sel
                                        visible: row.w === "select"
                                        property bool expanded: false
                                        property int hover: -1
                                        activeFocusOnTab: visible && row.ready
                                        onActiveFocusChanged: { if (activeFocus) list.show(row); else expanded = false; }
                                        function pick(d) {
                                            const i = row.opts.findIndex(o => o.value === String(row.value));
                                            const n = Math.max(0, Math.min(row.opts.length - 1, i + d));
                                            if (n !== i) win.change(row.s, row.opts[n].value);
                                        }
                                        Keys.onLeftPressed: pick(-1)
                                        Keys.onRightPressed: pick(1)
                                        Keys.onDownPressed: e => { if (expanded) hover = Math.min(row.opts.length - 1, hover + 1); else e.accepted = false; }
                                        Keys.onUpPressed: e => { if (expanded) hover = Math.max(0, hover - 1); else e.accepted = false; }
                                        Keys.onSpacePressed: { expanded = !expanded; hover = row.opts.findIndex(o => o.value === String(row.value)); }
                                        Keys.onReturnPressed: {
                                            if (expanded && hover >= 0 && row.opts[hover].value !== String(row.value)) win.change(row.s, row.opts[hover].value);
                                            expanded = !expanded;
                                            hover = row.opts.findIndex(o => o.value === String(row.value));
                                        }
                                        Keys.onEscapePressed: e => { if (expanded) expanded = false; else e.accepted = false; }
                                        Rectangle {
                                            width: Math.max(200, selText.implicitWidth + 44); height: 26
                                            color: "#0d0d12"
                                            border.color: sel.activeFocus ? win.theme.gold : win.theme.line
                                            Text {
                                                id: selText
                                                anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                                                text: row.opts.length ? win.textOf(row.s, row.value) : String(row.value === undefined ? "" : row.value)
                                                font { family: win.theme.mono; pixelSize: win.theme.px(12) }
                                                color: sel.activeFocus ? win.theme.goldHi : win.theme.text
                                            }
                                            Text { anchors { right: parent.right; rightMargin: 9; verticalCenter: parent.verticalCenter } text: sel.expanded ? "▴" : "▾"; color: win.theme.muted; font.pixelSize: win.theme.px(12) }
                                            MouseArea { anchors.fill: parent; onClicked: { sel.forceActiveFocus(); sel.expanded = !sel.expanded; } }
                                        }
                                        Rectangle {
                                            visible: sel.expanded
                                            width: Math.max(200, optCol.implicitWidth + 2); height: optCol.implicitHeight + 2
                                            color: win.theme.raised
                                            border.color: win.theme.line
                                            Column {
                                                id: optCol
                                                x: 1; y: 1
                                                Repeater {
                                                    model: sel.expanded ? row.opts : []
                                                    delegate: Rectangle {
                                                        id: opt
                                                        required property var modelData
                                                        required property int index
                                                        readonly property bool on: String(row.value) === modelData.value
                                                        width: Math.max(198, optText.implicitWidth + 24); height: 24
                                                        color: sel.hover === index ? win.theme.surface : "transparent"
                                                        Rectangle { visible: opt.on; width: 2; height: parent.height; color: win.theme.gold }
                                                        Text { id: optText; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: opt.modelData.text; font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: opt.on } color: opt.on ? win.theme.goldHi : win.theme.text }
                                                        MouseArea {
                                                            anchors.fill: parent; hoverEnabled: true
                                                            onEntered: sel.hover = opt.index
                                                            onClicked: { if (!opt.on) win.change(row.s, opt.modelData.value); sel.expanded = false; }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // slider for numbers: ←/→ step, drag; applied when you stop
                                    Item {
                                        id: sld
                                        visible: row.w === "slider"
                                        width: 300; height: 24
                                        activeFocusOnTab: visible && row.ready
                                        onActiveFocusChanged: if (activeFocus) list.show(row)
                                        property real local: Number(row.value)
                                        property bool busy: false
                                        readonly property real lo: row.s.min !== undefined ? row.s.min : 0
                                        readonly property real hi: row.s.max !== undefined ? row.s.max : 100
                                        readonly property real st: row.s.step || 1
                                        readonly property real shown: busy ? local : Number(row.value)
                                        function setTo(v) {
                                            v = Math.round(Math.max(lo, Math.min(hi, v)) / st) * st;
                                            local = Number(v.toFixed(3));
                                            busy = true;
                                            commit.restart();
                                        }
                                        Timer { id: commit; interval: 500; onTriggered: { win.change(row.s, sld.local); sld.busy = false; } }
                                        Keys.onLeftPressed: setTo(shown - st)
                                        Keys.onRightPressed: setTo(shown + st)
                                        Rectangle {
                                            id: track
                                            width: 200; height: 6; anchors.verticalCenter: parent.verticalCenter
                                            color: "#0d0d12"; border.color: sld.activeFocus ? win.theme.gold : win.theme.line
                                            Rectangle { width: (parent.width - 2) * (sld.shown - sld.lo) / (sld.hi - sld.lo); height: 4; x: 1; y: 1; color: win.theme.gold }
                                            Rectangle {
                                                x: (parent.width - width) * (sld.shown - sld.lo) / (sld.hi - sld.lo); y: -5
                                                width: 8; height: 16; color: sld.activeFocus ? win.theme.goldHi : win.theme.text
                                            }
                                            MouseArea {
                                                anchors { fill: parent; topMargin: -8; bottomMargin: -8 }
                                                onPressed: m => { sld.forceActiveFocus(); sld.setTo(sld.lo + (sld.hi - sld.lo) * m.x / width); }
                                                onPositionChanged: m => sld.setTo(sld.lo + (sld.hi - sld.lo) * m.x / width)
                                            }
                                        }
                                        Text {
                                            anchors { left: track.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                            text: (sld.st < 1 ? sld.shown.toFixed(2).replace(/0$/, "") : Math.round(sld.shown)) + (row.s.unit ? " " + row.s.unit : "")
                                            font { family: win.theme.mono; pixelSize: win.theme.px(12) }
                                            color: sld.activeFocus ? win.theme.goldHi : win.theme.text
                                        }
                                    }

                                    // text
                                    Rectangle {
                                        id: fld
                                        visible: row.w === "field" && !row.s.readonly
                                        width: 300; height: 26
                                        color: "#0d0d12"
                                        border.color: fldIn.activeFocus ? win.theme.gold : win.theme.line
                                        TextInput {
                                            id: fldIn
                                            anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
                                            verticalAlignment: TextInput.AlignVCenter
                                            activeFocusOnTab: fld.visible && row.ready
                                            onActiveFocusChanged: if (activeFocus) list.show(row)
                                            clip: true
                                            text: row.value === undefined ? "" : String(row.value)
                                            font { family: win.theme.mono; pixelSize: win.theme.px(12) }
                                            color: win.theme.text
                                            Keys.onReturnPressed: win.change(row.s, text)
                                            onEditingFinished: if (text !== String(row.value)) win.change(row.s, text)
                                        }
                                    }

                                    // ── shortcut: click (or Enter) and press the keys; Esc cancels, Backspace = no shortcut
                                    Rectangle {
                                        id: kc
                                        visible: row.w === "keys"
                                        property bool listening: false
                                        // Hyprland's shortcuts pause while listening (olymparch.lua: submap olymparch-record)
                                        onListeningChanged: Hyprland.dispatch(listening ? 'hl.dsp.submap("olymparch-record")' : 'hl.dsp.submap("reset")')
                                        Component.onDestruction: if (listening) Hyprland.dispatch('hl.dsp.submap("reset")')
                                        Timer { running: kc.listening; interval: 15000; onTriggered: kc.listening = false }
                                        width: Math.max(200, kcText.implicitWidth + 24); height: 26
                                        color: listening ? "#17130b" : "#0d0d12"
                                        border.color: listening || activeFocus ? win.theme.gold : win.theme.line
                                        activeFocusOnTab: visible && row.ready
                                        onActiveFocusChanged: { if (activeFocus) list.show(row); else listening = false; }
                                        // Qt key → Hyprland key name (shifted digits on a US layout give the digit back)
                                        function keyName(e) {
                                            const k = e.key;
                                            if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
                                            if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
                                            if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1);
                                            const shifted = e.text ? "!@#$%^&*()".indexOf(e.text) : -1;
                                            if (shifted >= 0) return "1234567890"[shifted];
                                            const named = {
                                                [Qt.Key_Return]: "RETURN", [Qt.Key_Enter]: "RETURN", [Qt.Key_Space]: "SPACE", [Qt.Key_Comma]: "COMMA",
                                                [Qt.Key_Period]: "PERIOD", [Qt.Key_Minus]: "MINUS", [Qt.Key_Equal]: "EQUAL", [Qt.Key_Slash]: "SLASH",
                                                [Qt.Key_Backslash]: "BACKSLASH", [Qt.Key_Semicolon]: "SEMICOLON", [Qt.Key_Apostrophe]: "APOSTROPHE",
                                                [Qt.Key_BracketLeft]: "BRACKETLEFT", [Qt.Key_BracketRight]: "BRACKETRIGHT", [Qt.Key_Tab]: "TAB",
                                                [Qt.Key_Delete]: "DELETE", [Qt.Key_Insert]: "INSERT", [Qt.Key_Home]: "HOME", [Qt.Key_End]: "END",
                                                [Qt.Key_PageUp]: "PRIOR", [Qt.Key_PageDown]: "NEXT", [Qt.Key_Print]: "PRINT", [Qt.Key_Pause]: "PAUSE",
                                                [Qt.Key_Left]: "LEFT", [Qt.Key_Right]: "RIGHT", [Qt.Key_Up]: "UP", [Qt.Key_Down]: "DOWN", [Qt.Key_QuoteLeft]: "GRAVE"
                                            };
                                            return named[k] || "";
                                        }
                                        Keys.onPressed: e => {
                                            if (!listening) {
                                                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { listening = true; e.accepted = true; }
                                                return;
                                            }
                                            e.accepted = true;
                                            if (e.key === Qt.Key_Escape) { listening = false; return; }
                                            if (e.key === Qt.Key_Backspace && !e.modifiers) { listening = false; win.change(row.s, ""); return; }
                                            const name = keyName(e);
                                            if (!name) return;   // a modifier on its own: wait for the key
                                            const m = [];
                                            if (e.modifiers & Qt.MetaModifier) m.push("SUPER");
                                            if (e.modifiers & Qt.ControlModifier) m.push("CTRL");
                                            if (e.modifiers & Qt.AltModifier) m.push("ALT");
                                            if (e.modifiers & Qt.ShiftModifier) m.push("SHIFT");
                                            m.push(name);
                                            listening = false;
                                            win.change(row.s, m.join(" + "));
                                        }
                                        Text {
                                            id: kcText
                                            anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                                            text: kc.listening ? I18n.t("settings.keys.press", "Press the keys · Esc cancels · ⌫ none")
                                                : (row.value === "" ? I18n.t("settings.keys.none", "No shortcut") : String(row.value))
                                            font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: !kc.listening && row.value !== "" }
                                            color: kc.listening ? win.theme.goldHi : row.value === "" ? win.theme.muted : (kc.activeFocus ? win.theme.goldHi : win.theme.text)
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: { kc.forceActiveFocus(); kc.listening = !kc.listening; } }
                                    }

                                    // ── a list you click (Wi-Fi networks, Bluetooth devices): olymparch-settings items / pick
                                    Column {
                                        id: itm
                                        visible: row.w === "items"
                                        width: Math.min(parent.width, 520)
                                        spacing: 4
                                        readonly property var d: win.items[row.s.key] || { lines: [], message: "", busy: "" }
                                        Row {
                                            spacing: 8
                                            visible: itm.d.message === ""   // no adapter: nothing to search with
                                            Rectangle {
                                                id: scanBtn
                                                width: scanText.implicitWidth + 24; height: 26
                                                color: win.theme.raised
                                                border.color: activeFocus ? win.theme.gold : win.theme.line
                                                activeFocusOnTab: itm.visible && row.ready && itm.d.message === ""
                                                onActiveFocusChanged: if (activeFocus) list.show(row)
                                                Keys.onReturnPressed: win.loadItems(row.s.key, true)
                                                Keys.onSpacePressed: win.loadItems(row.s.key, true)
                                                Text { id: scanText; anchors.centerIn: parent; text: row.s.key === "audio.per_app" ? I18n.t("settings.items.refresh", "Refresh") : I18n.t("settings.items.scan", "Search again"); font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: true } color: scanBtn.activeFocus ? win.theme.goldHi : win.theme.text }
                                                MouseArea { anchors.fill: parent; onClicked: win.loadItems(row.s.key, true) }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: itm.d.busy !== ""
                                                text: itm.d.busy
                                                font { family: win.theme.mono; pixelSize: win.theme.px(12) }
                                                color: win.theme.goldHi
                                            }
                                        }
                                        Text {
                                            visible: itm.d.message !== ""
                                            width: itm.width
                                            wrapMode: Text.Wrap
                                            text: itm.d.message
                                            font { family: win.theme.mono; pixelSize: win.theme.px(12) }
                                            color: win.theme.muted
                                        }
                                        Repeater {
                                            model: itm.d.lines
                                            delegate: Rectangle {
                                                id: it
                                                required property var modelData
                                                readonly property bool on: modelData.state === "on"
                                                width: itm.width; height: 28
                                                color: activeFocus ? win.theme.raised : "#0d0d12"
                                                border.color: activeFocus ? win.theme.gold : win.theme.line
                                                activeFocusOnTab: itm.visible && row.ready
                                                onActiveFocusChanged: if (activeFocus) list.show(row)
                                                Keys.onReturnPressed: win.pickItem(row.s.key, modelData)
                                                Keys.onSpacePressed: win.pickItem(row.s.key, modelData)
                                                Keys.onLeftPressed: e => { if (it.level) win.pickItem(row.s.key, modelData, "down"); else e.accepted = false; }
                                                Keys.onRightPressed: e => { if (it.level) win.pickItem(row.s.key, modelData, "up"); else e.accepted = false; }
                                                readonly property bool level: modelData.state === "level"
                                                Rectangle { visible: it.on; width: 2; height: parent.height; color: win.theme.gold }
                                                Text {
                                                    anchors { left: parent.left; leftMargin: 10; right: itAct.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                                    text: it.modelData.name + (it.modelData.detail ? "  ·  " + it.modelData.detail : "")
                                                    elide: Text.ElideRight
                                                    font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: it.on }
                                                    color: it.on ? win.theme.goldHi : win.theme.text
                                                }
                                                Text {
                                                    id: itAct
                                                    visible: !it.level
                                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                                    text: it.on ? I18n.t("settings.items.disconnect", "Disconnect ›")
                                                        : it.modelData.state === "saved" ? I18n.t("settings.items.connect", "Connect ›")
                                                        : row.s.key === "bluetooth.devices" ? I18n.t("settings.items.pair", "Pair ›") : I18n.t("settings.items.connect", "Connect ›")
                                                    font { family: win.theme.mono; pixelSize: win.theme.px(11) }
                                                    color: it.activeFocus ? win.theme.goldHi : win.theme.muted
                                                }
                                                MouseArea { anchors.fill: parent; onClicked: win.pickItem(row.s.key, it.modelData) }
                                                // ── volume per app: − and + (←/→), clicking the name mutes
                                                Row {
                                                    visible: it.level
                                                    z: 2
                                                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                                    spacing: 4
                                                    Repeater {
                                                        model: [{ how: "down", text: "−" }, { how: "up", text: "+" }]
                                                        delegate: Rectangle {
                                                            id: volBtn
                                                            required property var modelData
                                                            width: 26; height: 20
                                                            color: volArea.containsMouse ? win.theme.surface : "transparent"
                                                            border.color: volArea.containsMouse ? win.theme.gold : win.theme.line
                                                            Text { anchors.centerIn: parent; text: volBtn.modelData.text; font { family: win.theme.mono; pixelSize: win.theme.px(13); bold: true } color: volArea.containsMouse ? win.theme.goldHi : win.theme.text }
                                                            MouseArea { id: volArea; anchors.fill: parent; hoverEnabled: true; onClicked: win.pickItem(row.s.key, it.modelData, volBtn.modelData.how) }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // shown, not set (About)
                                    Text {
                                        id: info2
                                        visible: row.s.readonly === true
                                        width: parent.width
                                        wrapMode: Text.Wrap
                                        lineHeight: 1.3
                                        text: row.s.key === "about.version" ? (win.about.version || "")
                                            : row.s.key === "about.hardware" ? ["cpu", "gpu", "memory", "kernel", "disk", "monitors"].filter(k => win.about[k]).map(k => I18n.t("settings.hw." + k, k.toUpperCase()) + "  " + win.about[k]).join("\n")
                                            : String(row.value || "")
                                        font { family: win.theme.mono; pixelSize: win.theme.px(12) }
                                        color: win.theme.text
                                    }

                                    // action
                                    Rectangle {
                                        id: btn
                                        visible: row.w === "button"
                                        width: btnText.implicitWidth + 24; height: 28
                                        color: activeFocus ? win.theme.raised : win.theme.raised
                                        border.color: activeFocus ? win.theme.gold : win.theme.line
                                        activeFocusOnTab: visible && row.ready
                                        onActiveFocusChanged: if (activeFocus) list.show(row)
                                        Keys.onReturnPressed: win.act(row.s)
                                        Keys.onSpacePressed: win.act(row.s)
                                        Text {
                                            id: btnText
                                            anchors.centerIn: parent
                                            text: win.tr(row.s.label) + " ›"
                                            font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: true }
                                            color: btn.activeFocus ? win.theme.goldHi : win.theme.text
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: win.act(row.s) }
                                    }

                                    // not built yet
                                    Rectangle {
                                        visible: !row.ready
                                        anchors { right: parent.right; top: parent.top }
                                        width: soon.implicitWidth + 12; height: 20
                                        color: "transparent"
                                        border.color: win.theme.line
                                        Text { id: soon; anchors.centerIn: parent; text: I18n.t("settings.soon", "coming"); font { family: win.theme.mono; pixelSize: win.theme.px(11) } color: win.theme.muted }
                                    }
                                }

                                // what an action printed (doctor …)
                                Rectangle {
                                    id: out
                                    visible: win.outputKey === row.s.key && win.output.length > 0
                                    y: Math.max(info.y + info.implicitHeight, ctl.y + ctl.height) + 8
                                    width: parent.width
                                    height: outText.implicitHeight + 16
                                    color: "#0d0d12"
                                    border.color: win.outputError ? win.theme.red : win.theme.line
                                    Text {
                                        id: outText
                                        x: 10; y: 8; width: parent.width - 20
                                        text: win.outputKey === row.s.key ? win.output : ""
                                        wrapMode: Text.Wrap
                                        font { family: win.theme.mono; pixelSize: win.theme.px(12) }
                                        color: win.outputError ? win.theme.red : win.theme.text
                                        textFormat: Text.PlainText
                                    }
                                }

                                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: win.theme.line }
                            }
                        }

                        // «+ 6 advanced»
                        Item {
                            width: content.width
                            visible: win.hiddenAdvanced.length > 0
                            height: visible ? moreText.implicitHeight + 18 : 0
                            Text {
                                id: moreText
                                y: 9; width: parent.width
                                text: I18n.t("settings.more", "+ %1 advanced: %2 · shown with «Advanced view»").arg(win.hiddenAdvanced.length)
                                      .arg(win.hiddenAdvanced.map(s => win.tr(s.label)).join(", "))
                                wrapMode: Text.Wrap
                                font { family: win.theme.mono; pixelSize: win.theme.px(11) }
                                color: win.theme.muted
                            }
                            MouseArea { anchors.fill: parent; onClicked: Settings.set("settings.advanced", true) }
                        }

                        Text {
                            visible: win.query && win.rows.length === 0
                            topPadding: 20
                            text: I18n.t("settings.nothing", "Nothing matches «%1».").arg(win.query)
                            font { family: win.theme.mono; pixelSize: win.theme.px(13) }
                            color: win.theme.muted
                        }
                    }
                }

                // where this page is saved, and back to defaults
                Item {
                    id: foot
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 14 }
                    height: 30
                    visible: !win.query
                    Text {
                        anchors { left: parent.left; right: defaults.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        readonly property var p: win.pageOf(win.page)
                        text: p ? I18n.t("settings.where", "Saved in %1").arg(p.where) + (p.command ? I18n.t("settings.same", " · same as %1").arg(p.command) : "") : ""
                        elide: Text.ElideRight
                        font { family: win.theme.mono; pixelSize: win.theme.px(11) }
                        color: win.theme.muted
                    }
                    Rectangle {
                        id: defaults
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: defText.implicitWidth + 24; height: 28
                        color: win.theme.raised
                        border.color: activeFocus ? win.theme.gold : win.theme.line
                        activeFocusOnTab: true
                        Keys.onReturnPressed: win.resetPage()
                        Keys.onSpacePressed: win.resetPage()
                        Text { id: defText; anchors.centerIn: parent; text: I18n.t("settings.defaults", "Defaults"); font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: true } color: defaults.activeFocus ? win.theme.goldHi : win.theme.text }
                        MouseArea { anchors.fill: parent; onClicked: win.resetPage() }
                    }
                }
            }
        }
    }

    // «Keep?» in the middle of every monitor; the first one takes the keyboard (Enter keeps, Esc goes back)
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: ask
            required property var modelData
            readonly property bool first: modelData === Quickshell.screens[0]
            screen: modelData
            visible: win.pending !== null
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "olymparch-settings-keep"
            WlrLayershell.keyboardFocus: visible && first ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#99060609"

            Rectangle {
                anchors.centerIn: parent
                width: 380
                height: askCol.implicitHeight + 28
                color: "#17130b"
                border.color: win.theme.gold
                focus: ask.first
                Keys.onReturnPressed: keepBtn.isDefault ? win.keep() : win.revert()
                Keys.onEscapePressed: win.revert()
                Keys.onTabPressed: keepBtn.isDefault = !keepBtn.isDefault
                Column {
                    id: askCol
                    x: 14; y: 14
                    width: parent.width - 28
                    spacing: 10
                    Text {
                        width: parent.width
                        text: I18n.t("settings.keep.title", "KEEP %1?").arg(win.pending ? win.pending.text : "")
                        wrapMode: Text.Wrap
                        font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: true; letterSpacing: 1 }
                        color: win.theme.goldHi
                    }
                    Text {
                        width: parent.width
                        text: I18n.t("settings.keep.body", "Goes back in %1 s if you don't answer. Esc goes back.").arg(win.countdown)
                        wrapMode: Text.Wrap
                        font { family: win.theme.mono; pixelSize: win.theme.px(13) }
                        color: win.theme.text
                    }
                    Row {
                        spacing: 8
                        Rectangle {
                            id: keepBtn
                            property bool isDefault: true
                            width: keepText.implicitWidth + 24; height: 28
                            color: win.theme.gold
                            border { color: isDefault ? win.theme.goldHi : win.theme.gold; width: isDefault ? 2 : 1 }
                            Text { id: keepText; anchors.centerIn: parent; text: I18n.t("settings.keep.yes", "Keep"); font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: true } color: "#0a0a0e" }
                            MouseArea { anchors.fill: parent; onClicked: win.keep() }
                        }
                        Rectangle {
                            width: backText.implicitWidth + 24; height: 28
                            color: win.theme.raised
                            border.color: keepBtn.isDefault ? win.theme.line : win.theme.gold
                            Text { id: backText; anchors.centerIn: parent; text: I18n.t("settings.keep.no", "Go back"); font { family: win.theme.mono; pixelSize: win.theme.px(12); bold: true } color: win.theme.text }
                            MouseArea { anchors.fill: parent; onClicked: win.revert() }
                        }
                    }
                }
            }
        }
    }
}
