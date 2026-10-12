// Super+K: every shortcut that works right now, with what it does, grouped and searchable. Read from Hyprland
// itself (hyprctl binds -j) each time it opens, so a shortcut moved in Settings shows where it is now; the names
// come from the schema's keys.* entries (their current combos) and your own shortcuts (keyboard.custom_keys).
// Type to search, ↑/↓ scroll, Esc clears the search, then closes.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: sheet
    required property var theme
    property bool open: false
    property string query: ""
    property var binds: []           // { group, label, keys: ["Super", "K"], words }
    readonly property string lang: I18n.lang
    function t(en, nb) { return lang === "nb" ? nb : en; }
    function tr(o) { return o ? (o[lang] || o.en || "") : ""; }

    GlobalShortcut {
        appid: "olymparch"
        name: "cheatsheet"
        description: "Show every keyboard shortcut"
        onPressed: sheet.open = !sheet.open
    }
    IpcHandler {
        target: "cheatsheet"
        function open(): void { sheet.open = true; }
        function close(): void { sheet.open = false; }
        function toggle(): void { sheet.open = !sheet.open; }
    }
    onOpenChanged: if (open) { query = ""; input.text = ""; flick.contentY = 0; hyprBinds.running = true; }
    Process {
        id: hyprBinds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: sheet.binds = sheet.describe(text) }
    }

    readonly property var groups: [
        { id: "start", en: "Open", nb: "Åpne" },
        { id: "windows", en: "Windows", nb: "Vinduer" },
        { id: "workspaces", en: "Workspaces", nb: "Arbeidsflater" },
        { id: "session", en: "Session", nb: "Økt" },
        { id: "media", en: "Media", nb: "Media" },
        { id: "own", en: "Your own", nb: "Dine egne" },
        { id: "other", en: "Other", nb: "Andre" }
    ]
    // schema key → group, and a shorter name where the schema label is written for Settings
    readonly property var place: ({
        "keys.olymparch_menu": "start", "keys.menu": "start", "keys.terminal": "start", "keys.settings": "start",
        "keys.cheatsheet": "start", "zeus.hotkey": "start",
        "keys.close": "windows", "keys.float": "windows", "keys.focus": "windows", "keys.mouse": "windows", "keys.add_game": "windows",
        "keys.workspace": "workspaces", "keys.move_to_workspace": "workspaces",
        "keys.lock": "session", "keys.exit": "session", "keys.media": "media"
    })
    function nameOf(e) {
        const special = {
            "keys.menu": t("Apps: search and start", "Apper: søk og start"),
            "keys.olymparch_menu": t("Olymparch menu", "Olymparch-menyen"),
            "zeus.hotkey": t("Zeus", "Zeus")
        };
        if (special[e.key]) return special[e.key];
        const l = tr(e.label).replace(/^(Shortcut|Hurtigtast): */, "");
        return l.charAt(0).toUpperCase() + l.slice(1);
    }
    // "SUPER + SHIFT + G" → a key that ignores spacing, case and the order of the modifiers
    function norm(combo) {
        const p = String(combo).split("+").map(s => s.trim().toUpperCase()).filter(s => s);
        const key = p.pop() || "";
        return p.sort().join("+") + "|" + key;
    }
    function mods(mask) {
        const out = [];
        if (mask & 64) out.push("SUPER");
        if (mask & 4) out.push("CTRL");
        if (mask & 8) out.push("ALT");
        if (mask & 1) out.push("SHIFT");
        return out;
    }
    function keyName(k) {
        const names = {
            RETURN: "Enter", SPACE: t("Space", "Mellomrom"), COMMA: ",", PERIOD: ".", ESCAPE: "Esc", TAB: "Tab",
            LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓", SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt",
            "MOUSE:272": t("Left button", "Venstre knapp"), "MOUSE:273": t("Right button", "Høyre knapp")
        };
        const u = String(k).toUpperCase();
        return names[u] || (u.startsWith("XF86") ? k.replace(/^XF86/, "") : u.length === 1 ? u : k);
    }
    function eachName(each) {
        if (each.includes("1") && each.includes("0")) return "1 … 0";
        if (each.includes("left")) return "← → ↑ ↓";
        if (each.some(x => x.startsWith("mouse:"))) return t("Left / right button", "Venstre / høyre knapp");
        return each.join(" ");
    }

    function describe(json) {
        let list = [];
        try { list = JSON.parse(json); } catch (e) { return []; }
        const entries = Settings.schema.settings.filter(e => e.binds);
        const own = Settings.get("keyboard.custom_keys") || [];
        const rows = [], done = {};
        for (const b of list) {
            if (b.submap) continue;   // Settings' recording mode
            const m = mods(b.modmask);
            const combo = m.concat([b.key]).join(" + ");
            const n = norm(combo);
            let hit = null;
            for (const e of entries) {
                const v = Settings.get(e.key);
                if (e.each) { if (typeof v === "string" && v && e.each.some(x => norm(v + " + " + x) === n)) hit = e; }
                else if (e.type === "text") { if (typeof v === "string" && v && norm(v) === n) hit = e; }
                else if (e.binds.some(rx => new RegExp(rx).test(combo))) hit = e;
                if (hit) break;
            }
            if (hit) {
                if (done[hit.key]) continue;
                done[hit.key] = true;
                const v = Settings.get(hit.key);
                const keys = hit.each ? String(v).split("+").map(s => keyName(s.trim())).concat([eachName(hit.each)])
                           : hit.type === "text" ? String(v).split("+").map(s => keyName(s.trim()))
                           : [t("Media keys", "Medietaster")];
                rows.push({ group: place[hit.key] || "other", label: nameOf(hit), keys: keys, order: Object.keys(place).indexOf(hit.key) });
                continue;
            }
            const mine = own.find(kv => Array.isArray(kv) && norm(kv[0]) === n);
            if (mine) { rows.push({ group: "own", label: mine[1], keys: m.concat([b.key]).map(keyName), order: 0 }); continue; }
            if (done["?" + n]) continue;
            done["?" + n] = true;
            rows.push({ group: "other", label: b.description || (b.dispatcher !== "__lua" ? (b.dispatcher + " " + b.arg).trim() : t("Set in your own Hyprland config", "Satt i din egen Hyprland-konfigurasjon")),
                        keys: m.concat([b.key]).map(keyName), order: 0 });
        }
        for (const r of rows) r.words = (r.label + " " + r.keys.join(" ") + " " + tr(groups.find(g => g.id === r.group))).toLowerCase();
        return rows;
    }
    readonly property var shown: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w);
        const rows = binds.filter(r => words.every(w => r.words.includes(w)));
        const out = [];
        for (const g of groups) {
            const in_ = rows.filter(r => r.group === g.id).sort((a, b) => a.order - b.order);
            if (in_.length) out.push({ header: tr(g), rows: in_ });
        }
        return out;
    }

    PanelWindow {
        visible: sheet.open
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-cheatsheet"
        WlrLayershell.keyboardFocus: sheet.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: sheet.open = false }

        Rectangle {
            id: panel
            width: Math.min(parent.width - 32, sheet.theme.px(720))
            height: Math.min(parent.height * 0.8, head.height + flick.contentHeight + 46)
            anchors.centerIn: parent
            color: sheet.theme.surface
            border.color: sheet.theme.line
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: sheet.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: sheet.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: sheet.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: sheet.theme.gold }
            MouseArea { anchors.fill: parent }

            Item {
                id: head
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                height: sheet.theme.px(32)
                Row {
                    id: title
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Text { text: ""; font { family: "Symbols Nerd Font Mono"; pixelSize: sheet.theme.px(14) } color: sheet.theme.gold; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: sheet.t("SHORTCUTS", "HURTIGTASTER")
                        font { family: sheet.theme.mono; pixelSize: sheet.theme.px(12); bold: true; letterSpacing: 2 }
                        color: sheet.theme.gold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Rectangle {
                    anchors { left: title.right; leftMargin: 16; right: parent.right; top: parent.top; bottom: parent.bottom }
                    color: "#0d0d12"
                    border.color: input.activeFocus ? sheet.theme.gold : sheet.theme.line
                    TextInput {
                        id: input
                        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        font { family: sheet.theme.mono; pixelSize: sheet.theme.px(13) }
                        color: sheet.theme.text
                        clip: true
                        focus: sheet.open
                        onTextEdited: { sheet.query = text; flick.contentY = 0; }
                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_Escape) { if (text) { text = ""; sheet.query = ""; } else sheet.open = false; }
                            else if (e.key === Qt.Key_Down) flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + 40);
                            else if (e.key === Qt.Key_Up) flick.contentY = Math.max(0, flick.contentY - 40);
                            else if (e.key === Qt.Key_PageDown) flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + flick.height - 40);
                            else if (e.key === Qt.Key_PageUp) flick.contentY = Math.max(0, flick.contentY - flick.height + 40);
                            else return;
                            e.accepted = true;
                        }
                        Text {
                            visible: !input.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: sheet.t("Search shortcuts …", "Søk i hurtigtaster …")
                            font: input.font
                            color: sheet.theme.muted
                        }
                    }
                }
            }

            Flickable {
                id: flick
                anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top; topMargin: 8; leftMargin: 16; rightMargin: 16 }
                contentHeight: col.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: col
                    width: flick.width
                    Text {
                        visible: sheet.shown.length === 0
                        topPadding: 10
                        text: sheet.binds.length ? sheet.t("No shortcut matches", "Ingen hurtigtast passer") : sheet.t("Reading the shortcuts …", "Leser hurtigtastene …")
                        font { family: sheet.theme.mono; pixelSize: sheet.theme.px(13) }
                        color: sheet.theme.muted
                    }
                    Repeater {
                        model: sheet.shown
                        delegate: Column {
                            id: grp
                            required property var modelData
                            width: col.width
                            Text {
                                topPadding: 10; bottomPadding: 4
                                text: grp.modelData.header.toUpperCase()
                                font { family: sheet.theme.mono; pixelSize: sheet.theme.px(10); letterSpacing: 1.5 }
                                color: sheet.theme.muted
                            }
                            Repeater {
                                model: grp.modelData.rows
                                delegate: Item {
                                    id: r
                                    required property var modelData
                                    width: grp.width
                                    height: sheet.theme.px(28)
                                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: sheet.theme.raised }
                                    Text {
                                        anchors { left: parent.left; right: caps.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                        text: r.modelData.label
                                        elide: Text.ElideRight
                                        font { family: sheet.theme.mono; pixelSize: sheet.theme.px(13) }
                                        color: sheet.theme.text
                                    }
                                    Row {
                                        id: caps
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                        spacing: 4
                                        Repeater {
                                            model: r.modelData.keys
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: cap.implicitWidth + 12
                                                height: sheet.theme.px(20)
                                                color: sheet.theme.raised
                                                border.color: sheet.theme.line
                                                Text {
                                                    id: cap
                                                    anchors.centerIn: parent
                                                    text: parent.modelData
                                                    font { family: sheet.theme.mono; pixelSize: sheet.theme.px(12); bold: true }
                                                    color: sheet.theme.goldHi
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: foot
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                height: sheet.theme.px(26)
                color: sheet.theme.bg
                Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: sheet.theme.line }
                Text {
                    anchors { left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    text: sheet.t("type  search     ↑↓  scroll     esc  close     change them in Settings → Keyboard",
                                  "skriv  søk     ↑↓  rull     esc  lukk     endre dem i Innstillinger → Tastatur")
                    font { family: sheet.theme.mono; pixelSize: sheet.theme.px(11) }
                    color: sheet.theme.muted
                }
            }
        }
    }
}
