// The Olymparch menu (Super+Alt+Space, or a click on the bolt in the bar): everything in one short list.
// Apps · Panels · Style · Install · Remove · Tools · Setup · Update · System · Help. Keyboard first: ↑/↓ choose, Enter or →
// opens, Esc or ← goes back (Backspace too when the search is empty), and typing searches every level at once.
// Install → Package searches the official Arch repositories (read-only) and installs one package through the narrow
// helper /usr/lib/olymparch/packages after you confirmed what it pulls in; Remove only lists what you installed
// yourself. The catalog of one-click apps is data: /usr/share/olymparch/menu/catalog.json (install-app IDs).
// Hooks other parts provide, each hidden or shown as «coming» while missing: `qs ipc call theme open`,
// olymparch-webapp, olymparch-tool NAME. `qs ipc call menu go install/package` opens a level directly.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: menu
    required property var theme
    property var launcher: null      // Launcher.qml: Apps opens it
    property var cheatsheet: null    // Cheatsheet.qml: Help → Keyboard shortcuts
    property bool open: false
    property var path: []            // node ids from the top, such as ["install", "package"]
    property string query: ""
    property var view: null          // a confirm, progress or text page on top of the list
    property int current: 0
    property real mouseX: -1         // where the pointer last moved (window coordinates)
    property real mouseY: -1
    readonly property string lang: I18n.lang
    readonly property string shellDir: "/usr/share/olymparch/shell"
    readonly property string helper: "/usr/lib/olymparch/packages"
    readonly property string repoUrl: "https://github.com/Thoaniel/olymparch"
    function t(en, nb) { return lang === "nb" ? nb : en; }
    function tr(o) { return o ? (o[lang] || o.en || "") : ""; }

    // ── what this machine has, asked on open
    property var have: ({})          // program → true
    property var owner: ({})         // catalog program → its package
    property bool themeIpc: false
    property var removable: []       // packages/removable
    property bool removableLoaded: false
    property var pkgResults: []      // Install → Package
    property bool pkgBusy: false
    property string pkgError: ""
    property bool busy: false        // an install or removal is running
    readonly property var catalog: {
        try { return JSON.parse(catalogFile.text()) || {}; } catch (e) { return { categories: [], apps: [] }; }
    }
    readonly property var tools: [
        { id: "screenshot", icon: "", en: "Screenshot", nb: "Skjermbilde" },
        { id: "record", icon: "", en: "Record the screen", nb: "Ta opp skjermen" },
        { id: "colorpicker", icon: "", en: "Colour picker", nb: "Fargevelger" },
        { id: "clipboard", icon: "", en: "Clipboard history", nb: "Utklippstavle" },
        { id: "emoji", icon: "", en: "Emoji", nb: "Emoji" }
    ]
    FileView { id: catalogFile; path: "/usr/share/olymparch/menu/catalog.json"; blockLoading: true; printErrors: false }

    function toggle() { open = !open; }
    GlobalShortcut {
        appid: "olymparch"
        name: "menu"
        description: "Open the Olymparch menu"
        onPressed: menu.toggle()
    }
    IpcHandler {
        target: "menu"
        function open(): void { menu.open = true; }
        function close(): void { menu.open = false; }
        function toggle(): void { menu.toggle(); }
        function go(where: string): void { menu.open = true; menu.goTo(where.split("/").filter(s => s)); }
    }

    onOpenChanged: {
        if (!open) return;
        mouseX = -1; mouseY = -1;
        if (busy) {   // back after the password prompt, or reopened while it works: where it was
            current = view && view.focus !== undefined ? view.focus : firstSelectable();
        } else {
            view = null; path = []; query = ""; pkgResults = []; pkgError = ""; current = 0;
        }
        probe.running = true;
    }

    // ── the tree. Every node: id, icon, label; children (a level), kind (a level filled at run time) or act.
    function node(id, icon, en, nb, more) {
        return Object.assign({ id: id, icon: icon, label: t(en, nb), words: (en + " " + nb).toLowerCase() }, more || {});
    }
    function term(cmd) {   // in a terminal that waits for Enter when done
        return ["foot", "-e", "sh", "-c", cmd + '; echo; printf "%s" "$1"; read -r _', "sh", t("Press Enter to close. ", "Trykk Enter for å lukke. ")];
    }
    function prettyKeys(combo) {   // "SUPER + K" → "Super+K", like the keycaps in the shortcut list
        return String(combo || "").split("+").map(s => s.trim()).filter(s => s)
            .map(s => s.length > 1 ? s.charAt(0) + s.slice(1).toLowerCase() : s).join("+");
    }
    function run(cmd) { Quickshell.execDetached(cmd); open = false; }
    function settingsPage(p) { run(["olymparch-settings", "open", p]); }
    readonly property var tree: {
        const wall = Settings.get("appearance.wallpaper");
        const bg = [["torch", "Torch (animated)", "Fakkel (levende)"], ["calm", "Calm (slower)", "Rolig (saktere)"], ["off", "Still", "Stille"]]
            .map(w => node("bg-" + w[0], w[0] === wall ? "" : "", w[1], w[2],
                           { hint: w[0] === wall ? t("in use", "i bruk") : "", stay: true, act: () => Settings.set("appearance.wallpaper", w[0]) }));
        const apps = (catalog.apps || []).map(a => {
            const cat = (catalog.categories || []).find(c => c.id === a.category);
            const installed = have[a.needs] === true;
            return node("app-" + a.id, installed ? "" : "", tr(a.name), tr(a.name), {
                sub: tr(a.description), hint: installed ? t("installed", "installert") : tr(cat ? cat.label : null),
                words: (a.name.en + " " + a.name.nb + " " + a.description.en + " " + a.description.nb).toLowerCase(),
                done: installed, act: installed ? null : () => confirmApp(a)
            });
        });
        const tools = menu.tools.filter(x => have["olymparch-tool"]).map(x => node("tool-" + x.id, x.icon, x.en, x.nb, { act: () => run(["olymparch-tool", x.id]) }));
        const coming = (id, icon, en, nb) => node(id, icon, en, nb, { disabled: true, hint: t("coming", "kommer") });
        // the bar's dropdown panels (Dropdown.qml, Panels.qml): the same panel the bar item, a hotkey and IPC open
        const panelNodes = Object.keys(Panels.registry).sort().map(name => {
            const p = Panels.registry[name];
            return node("panel-" + name, p.icon || "\u{F056E}", p.en || name, p.nb || p.en || name, {
                hint: p.setting ? prettyKeys(Settings.get(p.setting)) : "",
                act: () => { open = false; Panels.open(name, ""); }
            });
        });
        const top = [
            node("apps", "", "Apps", "Apper", { hint: t("search and start", "søk og start"), act: () => openLauncher() }),
            node("panels", "\u{F056E}", "Panels", "Paneler", { hint: t("the bar's dropdowns", "nedtrekkspanelene i baren"),
                children: panelNodes.length ? panelNodes : [coming("panels-none", "\u{F056E}", "No panels yet", "Ingen paneler ennå")] }),
            node("style", "", "Style", "Stil", { children: [
                node("theme", "", "Theme", "Tema", { hint: themeIpc ? "" : t("in Settings", "i Innstillinger"), act: () => openTheme() }),
                node("background", "", "Background", "Bakgrunn", { children: bg })
            ] }),
            node("install", "", "Install", "Installer", { children: [
                node("catalog", "", "Apps", "Apper", { hint: t("picked apps", "utvalgte apper"), children: apps.length ? apps : [coming("catalog-none", "", "More apps", "Flere apper")] }),
                have["olymparch-webapp"] ? node("webapp", "", "Web app", "Nettapp", { hint: t("a site as an app", "en nettside som app"), act: () => run(term("olymparch-webapp add")) })
                                         : coming("webapp", "", "Web app", "Nettapp"),
                node("package", "", "Package", "Pakke", { hint: t("official Arch repositories", "offisielle Arch-pakker"), kind: "pkgsearch" })
            ] }),
            node("remove", "", "Remove", "Fjern", { hint: t("what you installed", "det du har installert"), kind: "remove" }),
            tools.length ? node("tools", "", "Tools", "Verktøy", { children: tools })
                         : coming("tools", "", "Tools: screenshot, recording, colour picker …", "Verktøy: skjermbilde, opptak, fargevelger …"),
            node("setup", "", "Setup", "Oppsett", { children: [
                node("wifi", "", "Wi-Fi", "Wi-Fi", { act: () => settingsPage("network") }),
                node("bluetooth", "", "Bluetooth", "Bluetooth", { act: () => settingsPage("bluetooth") }),
                node("displays", "", "Displays", "Skjermer", { act: () => settingsPage("display") }),
                node("sound", "", "Sound", "Lyd", { act: () => settingsPage("audio") }),
                node("keyboard", "", "Keyboard", "Tastatur", { act: () => settingsPage("keyboard") }),
                node("all-settings", "", "All settings", "Alle innstillinger", { act: () => run(["olymparch-settings", "open"]) })
            ] }),
            node("update", "", "Update", "Oppdater", { children: [
                node("update-now", "", "Update now", "Oppdater nå", { hint: t("in a terminal", "i en terminal"), act: () => run(term("olymparch update")) }),
                node("changes", "", "What changed", "Hva som er endret", { hint: t("last update", "siste oppdatering"), act: () => showChanges() })
            ] }),
            node("system", "", "System", "System", { children: [
                node("lock", "", "Lock", "Lås", { act: () => run(["olymparch-lock"]) }),
                node("logout", "", "Log out", "Logg ut", { act: () => confirm(t("Log out?", "Logge ut?"), [t("Open apps are closed.", "Åpne apper lukkes.")], t("Log out", "Logg ut"), true, () => { open = false; Hyprland.dispatch("hl.dsp.exit()"); }) }),
                node("restart", "", "Restart", "Start på nytt", { act: () => confirm(t("Restart now?", "Starte på nytt nå?"), [t("Open apps are closed.", "Åpne apper lukkes.")], t("Restart", "Start på nytt"), true, () => run(["systemctl", "reboot"])) }),
                node("shutdown", "", "Shut down", "Slå av", { act: () => confirm(t("Shut down now?", "Slå av nå?"), [t("Open apps are closed.", "Åpne apper lukkes.")], t("Shut down", "Slå av"), true, () => run(["systemctl", "poweroff"])) }),
                node("rollback", "", "Snapshot rollback", "Rull tilbake til et øyeblikksbilde", { hint: t("in a terminal", "i en terminal"), act: () => run(["foot", "-e", "olymparch-rollback"]) })
            ] }),
            node("help", "", "Help", "Hjelp", { children: [
                node("keys", "", "Keyboard shortcuts", "Hurtigtaster", { hint: prettyKeys(Settings.get("keys.cheatsheet")), act: () => { open = false; if (cheatsheet) cheatsheet.open = true; } }),
                node("manual", "", "Manual", "Brukerveiledning", { hint: "github.com/Thoaniel/olymparch", act: () => run(["xdg-open", repoUrl]) }),
                node("report", "", "Report a bug", "Meld fra om en feil", { hint: t("you see the report before it is sent", "du ser rapporten før den sendes"), act: () => run(["olymparch-settings", "run", "about.report"]) })
            ] })
        ];
        const walk = (nodes, prefix, crumb) => nodes.forEach(n => {
            n.fullPath = prefix.concat([n.id]);
            n.crumb = crumb;
            if (n.children) walk(n.children, n.fullPath, crumb.concat([n.label]));
        });
        walk(top, [], []);
        return top;
    }
    function nodeAt(p) {
        let nodes = tree, n = null;
        for (const id of p) {
            n = (nodes || []).find(x => x.id === id);
            if (!n) return null;
            nodes = n.children;
        }
        return n;
    }
    readonly property var here: nodeAt(path)
    readonly property string kind: view ? view.kind : (here && here.kind) || ""
    readonly property var crumbs: {
        const out = [];
        for (let i = 1; i <= path.length; i++) { const n = nodeAt(path.slice(0, i)); if (n) out.push(n.label); }
        if (view && view.title) out.push(view.title);
        return out;
    }

    // ── the rows on screen: the level, search results across every level, or a view
    readonly property var rows: {
        if (view) return view.rows;
        if (kind === "pkgsearch") return pkgRows();
        if (query.trim() && kind === "remove") {   // what you can remove that matches first, then everything else
            const words = query.toLowerCase().split(/\s+/).filter(w => w);
            const mine = removeRows().filter(r => !r.text && words.every(w => (r.label + " " + (r.sub || "") + " " + r.hint).toLowerCase().includes(w)));
            return mine.concat(searchRows().filter(r => !(mine.length && r.text)));
        }
        if (query.trim()) return searchRows();
        if (kind === "remove") return removeRows();
        return here ? here.children : tree;
    }
    function searchRows() {
        const words = query.toLowerCase().split(/\s+/).filter(w => w);
        const out = [];
        const walk = nodes => nodes.forEach(n => {
            const hay = n.words + " " + n.label.toLowerCase() + " " + (n.sub || "").toLowerCase() + " " + n.crumb.join(" ").toLowerCase();
            if (words.every(w => hay.includes(w))) out.push(Object.assign({}, n, { showCrumb: true }));
            if (n.children) walk(n.children);
        });
        walk(tree);
        const q = query.trim().toLowerCase();
        if (/^[a-z0-9@._+-]+$/.test(q))
            out.push(node("pkg-search", "", "Search packages for «" + q + "»", "Søk etter pakker: «" + q + "»", { hint: t("Install → Package", "Installer → Pakke"), act: () => { goTo(["install", "package"]); query = q; } }));
        if (!out.length) out.push({ text: t("Nothing found", "Fant ingenting") });
        return out;
    }
    function pkgRows() {
        if (pkgError) return [{ text: pkgError, error: true }];
        if (!query.trim()) return [{ text: t("Type a package name. Only the official Arch repositories (core, extra, multilib) and Olymparch's own; never the AUR.",
                                            "Skriv et pakkenavn. Bare de offisielle Arch-pakkebrønnene (core, extra, multilib) og Olymparchs egen; aldri AUR.") }];
        if (pkgBusy && !pkgResults.length) return [{ text: t("Searching …", "Søker …") }];
        const q = query.trim().toLowerCase();
        const missing = !pkgBusy && /^[a-z0-9@._+-]+$/.test(q) && !pkgResults.some(p => p.name === q)
            ? [{ text: t(`«${q}» is not in the official repositories (the AUR is not supported here)`, `«${q}» finnes ikke i de offisielle pakkebrønnene (AUR støttes ikke her)`), error: true }] : [];
        if (!pkgResults.length) return missing.length ? missing : [{ text: t("No package by that name", "Ingen pakke med det navnet") }];
        return missing.concat(pkgResults.map(p => ({
            id: "pkg-" + p.name, icon: p.installed ? "" : "", label: p.name, sub: p.description,
            hint: p.installed ? t("installed", "installert") : p.repo + " · " + p.version, done: p.installed,
            act: p.installed ? null : () => previewInstall(p.name)
        })));
    }
    function removeRows() {
        if (!removableLoaded) return [{ text: t("Looking …", "Ser etter …") }];
        const out = [], seen = {};
        for (const a of (catalog.apps || [])) {
            const pkg = owner[a.needs];
            if (pkg && removable.includes(pkg) && !seen[pkg]) {
                seen[pkg] = true;
                out.push({ id: "rm-" + pkg, icon: "", label: tr(a.name), sub: tr(a.description), hint: pkg, act: () => previewRemove(pkg, tr(a.name)) });
            }
        }
        for (const p of removable) if (!seen[p]) out.push({ id: "rm-" + p, icon: "", label: p, hint: t("package", "pakke"), act: () => previewRemove(p, p) });
        if (!out.length) out.push({ text: t("Nothing you installed yourself. System packages are never removed here.", "Ingenting du har installert selv. Systempakker fjernes aldri her.") });
        return out;
    }
    readonly property bool selectable: rows.length > 0 && rows.some(r => !r.text && !r.disabled)
    onRowsChanged: {
        if (current >= rows.length || !rows[current] || rows[current].text || rows[current].disabled) {
            current = view && view.focus !== undefined ? view.focus : rows.findIndex(r => !r.text && !r.disabled);
            if (current < 0) current = 0;
        }
    }
    function firstSelectable() { return Math.max(0, rows.findIndex(r => !r.text && !r.disabled)); }
    function move(d) {
        let i = current;
        for (let n = 0; n < rows.length; n++) {
            i = (i + d + rows.length) % rows.length;
            if (!rows[i].text && !rows[i].disabled) { current = i; return; }
        }
    }

    // ── going places
    function goTo(p) { view = null; query = ""; path = p; current = 0; enter(); }
    function enter() {
        if (kind === "remove") loadRemovable();
        if (kind === "pkgsearch") { pkgResults = []; pkgError = ""; }
    }
    function back() {
        if (busy && view && view.kind === "run") { open = false; return; }   // it goes on; a notification says when done
        if (view) { view = null; current = 0; return; }
        if (path.length) { const was = path[path.length - 1]; path = path.slice(0, -1); query = ""; current = Math.max(0, rows.findIndex(r => r.id === was)); return; }
        open = false;
    }
    function activate(i) {
        const r = rows[i];
        if (!r || r.text || r.disabled) return;
        if (r.children || r.kind) {
            goTo(r.fullPath);
            return;
        }
        if (r.act) { r.act(); if (r.stay) return; }
    }
    function openLauncher() { open = false; if (launcher) launcher.open = true; }
    function openTheme() {
        open = false;
        Quickshell.execDetached(["sh", "-c", 'if qs ipc -p "$1" show 2>/dev/null | grep -qx "target theme"; then exec qs ipc -p "$1" call theme open; else exec olymparch-settings open appearance; fi', "sh", shellDir]);
    }

    // ── views: confirm, progress, text
    function confirm(title, lines, yes, danger, onYes) {
        const rows = [{ text: title, heading: true }].concat(lines.map(l => ({ text: l })));
        rows.push({ id: "yes", icon: danger ? "" : "", label: yes, danger: danger, act: onYes });
        rows.push({ id: "no", icon: "", label: t("Cancel", "Avbryt"), act: () => back() });
        view = { kind: "confirm", title: title, rows: rows, focus: danger ? rows.length - 1 : rows.length - 2 };
        current = view.focus;
    }
    function textView(title, lines) {
        view = { kind: "text", title: title, rows: lines.map(l => ({ text: l })).concat([{ id: "back", icon: "", label: t("Back", "Tilbake"), act: () => back() }]) };
        current = view.rows.length - 1;
    }
    function showChanges() {
        textView(t("What changed", "Hva som er endret"), [t("Reading the package log …", "Leser pakkeloggen …")]);
        changes.running = true;
    }
    Process {
        id: changes
        command: ["olymparch-changes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim()).map(l => menu.changeLine(l));
                const shown = lines.slice(-14);
                if (lines.length > shown.length) shown.unshift(t(`… and ${lines.length - shown.length} more`, `… og ${lines.length - shown.length} til`));
                if (menu.view && menu.view.kind === "text") menu.textView(menu.t("What changed", "Hva som er endret"), shown.length ? shown : [menu.t("Nothing yet", "Ingenting ennå")]);
            }
        }
    }

    // "2026-10-12T16:29:13+0200  installed cowsay (3.8.4-1)" → "12. okt. 16:29 · installert cowsay (3.8.4-1)"
    function changeLine(l) {
        const m = l.match(/^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d)\S*\s+(\w+)\s+(.*)$/);
        if (!m) return l;
        const months = lang === "nb" ? ["jan.", "feb.", "mars", "apr.", "mai", "juni", "juli", "aug.", "sep.", "okt.", "nov.", "des."]
                                     : ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const verbs = { upgraded: t("updated", "oppdatert"), installed: t("installed", "installert"), removed: t("removed", "fjernet"), downgraded: t("downgraded", "nedgradert") };
        return `${parseInt(m[3])}. ${months[parseInt(m[2]) - 1]} ${m[4]}:${m[5]} · ${verbs[m[6]] || m[6]} ${m[7]}`;
    }
    // a one-click app from the catalog: install-app's fixed list decides the packages
    function confirmApp(a) {
        confirm(t("Install ", "Installere ") + tr(a.name) + "?", [tr(a.description), t("From the official Arch repositories. Takes a minute.", "Fra de offisielle Arch-pakkebrønnene. Tar et minutt.")],
                t("Install", "Installer"), false, () => runJob(t("Installing ", "Installerer ") + tr(a.name), ["pkexec", "/usr/lib/olymparch/install-app", a.install], tr(a.name), true));
    }
    // Install → Package: what it pulls in first (read-only, as you), then the helper through pkexec
    function previewInstall(name) { previewJob("install", name, name); }
    function previewRemove(name, label) { previewJob("remove", name, label); }
    function previewJob(action, name, label) {
        view = { kind: "confirm", title: label, checking: name, rows: [{ text: t("Checking …", "Sjekker …") }] };
        preview.action = action; preview.name = name; preview.label = label;
        preview.command = [helper, "preview", action, name];
        preview.running = true;
    }
    function size(b) {
        const s = b >= 1048576 ? (b / 1048576).toFixed(1) + " MiB" : Math.max(1, Math.round(b / 1024)) + " KiB";
        return lang === "nb" ? s.replace(".", ",") : s;
    }
    Process {
        id: preview
        property string action
        property string name
        property string label
        stdout: StdioCollector { id: previewOut }
        stderr: StdioCollector { id: previewErr }
        onExited: code => {
            if (!menu.view || menu.view.checking !== name) return;   // gone back in the meantime
            const lines = previewOut.text.split("\n").filter(l => l.trim()).map(l => l.split("\t"));
            const inst = action === "install";
            if (code !== 0) {
                const why = previewErr.text.trim().replace(/^packages: /, "") || menu.t("The helper is missing (olymparch update)", "Hjelperen mangler (olymparch update)");
                menu.view = { kind: "confirm", title: label, rows: [{ text: why, error: true }, { id: "back", icon: "", label: menu.t("Back", "Tilbake"), act: () => menu.back() }] };
                menu.current = 1;
                return;
            }
            if (inst && !lines.length) { menu.textView(name, [menu.t(name + " is already installed", name + " er allerede installert")]); return; }
            const total = lines.reduce((s, l) => s + (parseInt(l[2]) || 0), 0);
            const list = lines.slice(0, 8).map(l => {
                const pkg = l[0].replace(/^[^/]*\//, "");
                const note = pkg === name ? "" : inst ? menu.t(`  (needed by ${name})`, `  (trengs av ${name})`) : menu.t("  (no longer used)", "  (ikke lenger i bruk)");
                return "  " + l[0] + "  " + (l[1] || "") + note;
            });
            if (lines.length > 8) list.push(menu.t(`  … and ${lines.length - 8} more`, `  … og ${lines.length - 8} til`));
            const n = lines.length;
            const head = inst ? menu.t(`This is installed (${n} package${n > 1 ? "s" : ""}` + (total ? `, ${menu.size(total)}):` : "):"),
                                       `Dette installeres (${n} pakke${n > 1 ? "r" : ""}` + (total ? `, ${menu.size(total)}):` : "):"))
                              : menu.t(`This is removed (${n} package${n > 1 ? "s" : ""}):`, `Dette fjernes (${n} pakke${n > 1 ? "r" : ""}):`);
            const what = (inst ? menu.t("install ", "installere ") : menu.t("remove ", "fjerne ")) + label + menu.t(` (${n}\u00a0package${n > 1 ? "s" : ""})`, ` (${n}\u00a0pakke${n > 1 ? "r" : ""})`);
            menu.confirm(inst ? menu.t("Install ", "Installere ") + label + "?" : menu.t("Remove ", "Fjerne ") + label + "?", [head].concat(list),
                         inst ? menu.t("Install", "Installer") : menu.t("Remove", "Fjern"), !inst,
                         () => menu.runJob((inst ? menu.t("Installing ", "Installerer ") : menu.t("Removing ", "Fjerner ")) + label,
                                           ["pkexec", menu.helper, action, name], label, inst, what));
        }
    }

    // progress: the helper's output as it comes; Esc hides the menu and a notification says when it is done.
    // The package helper asks for your password (PasswordPrompt.qml): the menu steps aside until it is typed.
    property bool waitingAuth: false
    property string authWhat: ""     // what the password is for, shown in the prompt («installere cowsay (2 pakker)»)
    function runJob(title, cmd, label, inst, asks) {
        busy = true;
        view = { kind: "run", title: title, label: label, inst: inst, lines: [], done: false, rows: [{ text: title + " …", big: true }] };
        job.command = cmd;
        job.running = true;
        if (asks) { authWhat = asks; waitingAuth = true; open = false; }
    }
    // pacman's own questions (answered by --noconfirm) and pkexec's English errors stay out of the log
    function noise(l) { return !l.trim() || /\[[Yy]\/[Nn]\]|^:: Proceed|Do you want to|^Error executing command|^This incident|^==/.test(l); }
    function jobLine(l, fromHelper) {
        if (waitingAuth && fromHelper) { waitingAuth = false; authWhat = ""; open = true; }   // the helper runs: the password was right
        if (!view || view.kind !== "run" || noise(l)) return;
        const lines = view.lines.concat([l.trim()]).slice(-6);
        const step = (l.match(/^(?:installing|removing|upgrading) (\S+?)\.\.\./) || [])[1];
        const status = view.title + (step ? "  ·  " + step : "") + " …";
        view = Object.assign({}, view, { lines: lines, status: status, rows: [{ text: status, big: true }].concat(lines.map(x => ({ text: x, dim: true }))) });
    }
    Process {
        id: job
        stdout: SplitParser { onRead: l => menu.jobLine(l, true) }
        stderr: SplitParser { onRead: l => menu.jobLine(l, false) }
        onExited: code => {
            const v = menu.view && menu.view.kind === "run" ? menu.view : { lines: [], label: "", inst: true };
            const ok = code === 0;
            const denied = menu.waitingAuth && (code === 126 || code === 127);   // pkexec: cancelled, or a wrong password
            const msg = ok ? (v.inst ? menu.t("Installed: ", "Installert: ") : menu.t("Removed: ", "Fjernet: ")) + v.label
                      : denied ? menu.t("Cancelled – nothing was changed", "Avbrutt – ingenting ble endret")
                      : menu.t("Did not work. Details: /var/log/olymparch-packages.log", "Det gikk ikke. Detaljer: /var/log/olymparch-packages.log");
            if (!menu.open && !menu.waitingAuth) Quickshell.execDetached(["notify-send", "-a", "Olymparch", msg]);
            const title = ok ? (v.inst ? menu.t("Installed", "Installert") : menu.t("Removed", "Fjernet"))
                        : denied ? menu.t("Cancelled", "Avbrutt") : (v.inst ? menu.t("Not installed", "Ikke installert") : menu.t("Not removed", "Ikke fjernet"));
            const rows = [{ text: (ok ? "✓  " : denied ? "" : "✗  ") + msg, big: true, ok: ok, error: !ok && !denied }].concat((denied ? [] : v.lines).map(x => ({ text: x, dim: true })));
            rows.push({ id: "back", icon: "", label: menu.t("Back", "Tilbake"), act: () => menu.back() });
            menu.authWhat = "";
            menu.view = Object.assign({}, v, { kind: "result", title: title, done: true, rows: rows, focus: rows.length - 1 });
            menu.current = rows.length - 1;
            if (menu.waitingAuth) { menu.waitingAuth = false; menu.open = true; }
            menu.busy = false;
            probe.running = true;
            if (menu.removableLoaded) menu.loadRemovable();
            if (menu.query.trim()) search.restart();
        }
    }

    // ── what is here: programs (hooks, catalog apps), the package behind each catalog app, the theme picker
    Process {
        id: probe
        command: ["sh", "-c", 'for c in "$@"; do p=$(command -v -- "$c") || continue; echo "have $c"; o=$(pacman -Qqo -- "$p" 2>/dev/null) && echo "owner $c $o"; done; qs ipc -p /usr/share/olymparch/shell show 2>/dev/null | grep -qx "target theme" && echo theme; true',
                  "sh", "olymparch-tool", "olymparch-webapp", "olymparch-rollback"].concat((menu.catalog.apps || []).map(a => a.needs).filter(n => /^[a-z0-9][a-z0-9._+-]*$/.test(n)))
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {}, o = {};
                let th = false;
                for (const l of text.split("\n")) {
                    const f = l.split(" ");
                    if (f[0] === "have") h[f[1]] = true;
                    else if (f[0] === "owner") o[f[1]] = f[2];
                    else if (f[0] === "theme") th = true;
                }
                menu.have = h; menu.owner = o; menu.themeIpc = th;
            }
        }
    }
    function loadRemovable() { removableProc.running = false; removableProc.running = true; }
    Process {
        id: removableProc
        command: [menu.helper, "removable"]
        stdout: StdioCollector {
            onStreamFinished: { menu.removable = text.split("\n").filter(l => l.trim()); menu.removableLoaded = true; }
        }
    }
    // Install → Package: pacman -Ss through the helper (read-only), a moment after you stop typing
    // the field shows the search, or nothing while a confirm/progress page is up (its hint says what keys do)
    function syncInput() { const want = view ? "" : query; if (input.text !== want) input.text = want; }
    onViewChanged: syncInput()
    onQueryChanged: {
        syncInput();
        if (kind === "pkgsearch") { pkgError = ""; search.restart(); }
    }
    Timer { id: search; interval: 350; onTriggered: menu.searchPackages() }
    function searchPackages() {
        const words = query.toLowerCase().split(/\s+/).filter(w => w);
        if (!words.length) { pkgResults = []; return; }
        if (words.some(w => !/^[a-z0-9@._+-]+$/.test(w) || w.startsWith("-")) || words.length > 4) {
            pkgResults = []; pkgError = t("A package name can only have lower-case letters, digits and @ . _ + -", "Pakkenavn kan bare ha små bokstaver, sifre og @ . _ + -"); return;
        }
        if (words.join("").length < 2) { pkgResults = []; return; }
        pkgBusy = true;
        pkgSearch.running = false;
        pkgSearch.command = [helper, "search"].concat(words);
        pkgSearch.running = true;
    }
    Process {
        id: pkgSearch
        stdout: StdioCollector {
            onStreamFinished: {
                menu.pkgBusy = false;
                const q = menu.query.trim().toLowerCase().split(/\s+/)[0];
                const res = text.split("\n").filter(l => l.trim()).map(l => {
                    const f = l.split("\t");
                    const rn = f[0].split("/");
                    return { repo: rn[0], name: rn[1], version: f[1], description: f[2], installed: f[3] === "installed" };
                });
                // exact name first, then names starting with it, then the rest
                const rank = p => p.name === q ? 0 : p.name.startsWith(q) ? 1 : p.name.includes(q) ? 2 : 3;
                res.sort((a, b) => rank(a) - rank(b) || a.name.length - b.name.length || a.name.localeCompare(b.name));
                menu.pkgResults = res.slice(0, 30);
            }
        }
    }

    // ── the window
    PanelWindow {
        visible: menu.open
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-menu"
        WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: menu.open = false }

        Rectangle {
            id: panel
            readonly property int rowH: menu.theme.px(30)
            width: Math.min(parent.width - 32, menu.theme.px(600))
            height: header.height + searchBox.height + listBox.height + footer.height + 30
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.18)
            color: menu.theme.surface
            border.color: menu.theme.line
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: menu.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: menu.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: menu.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: menu.theme.gold }
            MouseArea { anchors.fill: parent }

            // where you are: ⚡ OLYMPARCH › Install › Package
            Row {
                id: header
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16; topMargin: 12 }
                height: menu.theme.px(20)
                spacing: 8
                clip: true
                Text { text: ""; font { family: "Symbols Nerd Font Mono"; pixelSize: menu.theme.px(14) } color: menu.theme.gold; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "OLYMPARCH"
                    font { family: menu.theme.mono; pixelSize: menu.theme.px(12); bold: true; letterSpacing: 2 }
                    color: menu.path.length || menu.view ? menu.theme.muted : menu.theme.gold
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; onClicked: { menu.view = null; menu.path = []; menu.query = ""; } }
                }
                Repeater {
                    model: menu.crumbs
                    delegate: Text {
                        required property var modelData
                        required property int index
                        text: "›  " + modelData
                        font { family: menu.theme.mono; pixelSize: menu.theme.px(12); bold: index === menu.crumbs.length - 1 }
                        color: index === menu.crumbs.length - 1 ? menu.theme.goldHi : menu.theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                id: searchBox
                anchors { left: parent.left; right: parent.right; top: header.bottom; leftMargin: 12; rightMargin: 12; topMargin: 10 }
                height: menu.theme.px(32)
                color: "#0d0d12"
                border.color: input.activeFocus && !menu.view ? menu.theme.gold : menu.theme.line
                Text {
                    id: glass
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: menu.kind === "pkgsearch" ? "" : ""
                    font { family: "Symbols Nerd Font Mono"; pixelSize: menu.theme.px(13) }
                    color: menu.theme.muted
                }
                TextInput {
                    id: input
                    anchors { left: glass.right; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    font { family: menu.theme.mono; pixelSize: menu.theme.px(14) }
                    color: menu.theme.text
                    selectionColor: menu.theme.gold
                    clip: true
                    focus: menu.open
                    readOnly: menu.view !== null
                    text: menu.view ? "" : menu.query
                    onTextEdited: { menu.query = text; menu.current = menu.firstSelectable(); }
                    Keys.onPressed: e => {
                        const empty = !menu.query;
                        if (e.key === Qt.Key_Escape) { if (menu.query && !menu.view) menu.query = ""; else menu.back(); }
                        else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) menu.move(1);
                        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) menu.move(-1);
                        else if (e.key === Qt.Key_PageDown) { for (let i = 0; i < 5; i++) menu.move(1); }
                        else if (e.key === Qt.Key_PageUp) { for (let i = 0; i < 5; i++) menu.move(-1); }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) menu.activate(menu.current);
                        else if (e.key === Qt.Key_Right && (empty || menu.view)) { const r = menu.rows[menu.current]; if (r && (r.children || r.kind)) menu.activate(menu.current); }
                        else if ((e.key === Qt.Key_Left || e.key === Qt.Key_Backspace) && (empty || menu.view)) menu.back();
                        else return;
                        e.accepted = true;
                    }
                    Text {
                        visible: !input.text
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        elide: Text.ElideRight
                        text: menu.view ? (menu.kind === "run" ? menu.t("Working … Esc hides this, it goes on", "Jobber … Esc skjuler dette, det fortsetter") : menu.t("Enter chooses · Esc goes back", "Enter velger · Esc går tilbake"))
                            : menu.kind === "pkgsearch" ? menu.t("Package name, such as cowsay …", "Pakkenavn, som cowsay …")
                            : menu.t("Search everything …", "Søk i alt …")
                        font: input.font
                        color: menu.theme.muted
                    }
                }
            }

            Item {
                id: listBox
                anchors { left: parent.left; right: parent.right; top: searchBox.bottom; topMargin: 8; leftMargin: 6; rightMargin: 6 }
                height: Math.min(menu.rows.length, 12) * panel.rowH
                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    model: menu.rows
                    currentIndex: menu.current
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: index === menu.current && !modelData.text && !modelData.disabled
                        width: list.width
                        height: panel.rowH
                        Rectangle { anchors.fill: parent; color: row.isCurrent ? menu.theme.raised : "transparent" }
                        Rectangle { visible: row.isCurrent; width: 2; height: parent.height; color: row.modelData.danger ? menu.theme.red : menu.theme.gold }
                        // a line of text (what a preview pulls in, progress, a hint)
                        Text {
                            visible: !!row.modelData.text
                            anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: row.modelData.text || ""
                            elide: Text.ElideRight
                            font { family: menu.theme.mono; pixelSize: menu.theme.px(row.modelData.dim ? 12 : row.modelData.big || row.modelData.heading ? 14 : 13); bold: !!(row.modelData.big || row.modelData.heading) }
                            color: row.modelData.error ? menu.theme.red : row.modelData.ok ? menu.theme.goldHi : row.modelData.dim ? menu.theme.muted : menu.theme.text
                            wrapMode: Text.NoWrap
                        }
                        Text {
                            id: icon
                            visible: !row.modelData.text
                            x: 12; width: menu.theme.px(18)
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.icon || ""
                            horizontalAlignment: Text.AlignHCenter
                            font { family: "Symbols Nerd Font Mono"; pixelSize: menu.theme.px(13) }
                            color: row.modelData.disabled ? menu.theme.line : row.modelData.danger ? menu.theme.red : row.isCurrent || row.modelData.done ? menu.theme.gold : menu.theme.muted
                        }
                        Row {
                            visible: !row.modelData.text
                            anchors { left: icon.right; leftMargin: 10; right: hint.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            clip: true
                            Text {
                                id: crumb
                                visible: !!row.modelData.showCrumb && row.modelData.crumb && row.modelData.crumb.length > 0
                                text: (row.modelData.crumb || []).join(" › ") + " ›"
                                font { family: menu.theme.mono; pixelSize: menu.theme.px(12) }
                                color: menu.theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: label
                                text: row.modelData.label || ""
                                font { family: menu.theme.mono; pixelSize: menu.theme.px(14); bold: row.isCurrent }
                                color: row.modelData.disabled ? menu.theme.muted : row.modelData.danger ? menu.theme.red : row.isCurrent ? menu.theme.goldHi : menu.theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: !!row.modelData.sub
                                width: Math.max(0, parent.width - label.width - (crumb.visible ? crumb.width + 10 : 0) - 10)
                                text: row.modelData.sub || ""
                                elide: Text.ElideRight
                                font { family: menu.theme.mono; pixelSize: menu.theme.px(12) }
                                color: menu.theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            id: hint
                            visible: !row.modelData.text
                            anchors { right: chevron.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: row.modelData.hint || ""
                            font { family: menu.theme.mono; pixelSize: menu.theme.px(12); italic: !!row.modelData.disabled }
                            color: menu.theme.muted
                        }
                        Text {
                            id: chevron
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            width: menu.theme.px(10)
                            text: !row.modelData.text && (row.modelData.children || row.modelData.kind) ? "›" : ""
                            font { family: menu.theme.mono; pixelSize: menu.theme.px(15); bold: true }
                            color: row.isCurrent ? menu.theme.gold : menu.theme.muted
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !row.modelData.text && !row.modelData.disabled
                            // only a mouse that really moved picks a row: a still pointer under rows that change
                            // (typing, going into a level) must not steal the keyboard's choice
                            onPositionChanged: mouse => {
                                const p = mapToItem(null, mouse.x, mouse.y);
                                if (p.x === menu.mouseX && p.y === menu.mouseY) return;
                                const first = menu.mouseX < 0;   // the first event after opening only says where it is
                                menu.mouseX = p.x; menu.mouseY = p.y;
                                if (!first) menu.current = row.index;
                            }
                            onClicked: menu.activate(row.index)
                        }
                    }
                }
            }

            // the keys that work here
            Rectangle {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                height: menu.theme.px(26)
                color: menu.theme.bg
                Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: menu.theme.line }
                Text {
                    anchors { left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    text: menu.kind === "run" ? menu.t("esc  hide (it goes on)", "esc  skjul (det fortsetter)")
                        : menu.view ? menu.t("↑↓  choose     ⏎  ok     esc  back", "↑↓  velg     ⏎  ok     esc  tilbake")
                        : menu.kind === "pkgsearch" ? (menu.rows[menu.current] && menu.rows[menu.current].act ? menu.t("↑↓  choose     ⏎  install …     esc  back     type  search", "↑↓  velg     ⏎  installer …     esc  tilbake     skriv  søk") : menu.t("↑↓  choose     esc  back     type  search", "↑↓  velg     esc  tilbake     skriv  søk"))
                        : menu.path.length ? menu.t("↑↓  choose     ⏎ →  open     esc ←  back     type  search all", "↑↓  velg     ⏎ →  åpne     esc ←  tilbake     skriv  søk i alt")
                        : menu.t("↑↓  choose     ⏎ →  open     esc  close     type  search all", "↑↓  velg     ⏎ →  åpne     esc  lukk     skriv  søk i alt")
                    font { family: menu.theme.mono; pixelSize: menu.theme.px(11) }
                    color: menu.theme.muted
                }
            }
        }
    }
}
