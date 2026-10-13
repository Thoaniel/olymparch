pragma Singleton
// The bar's dropdown panels: which one is open (at most one, on one monitor), and the list of panels for the
// menu's «Panels» level and `qs ipc call panel …`. Each panel is a Dropdown.qml under its bar item; this only
// holds the state, so the bar item, the menu, a hotkey and IPC all open the same panel.
//   qs ipc -p /usr/share/olymparch/shell call panel toggle zeus      open | toggle | close NAME, list
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: panels
    property string current: ""   // the open panel, "" for none
    property string screen: ""    // the monitor it is open on (a bar per monitor)
    // name → { icon, en, nb, setting } (setting: the hotkey's setting key, shown in the menu and the cheatsheet)
    property var registry: ({})

    function register(name, info) {
        if (JSON.stringify(registry[name]) === JSON.stringify(info)) return;
        const r = Object.assign({}, registry);
        r[name] = info;
        registry = r;
    }
    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
    }
    function open(name, screenName) {
        if (!registry[name]) return false;
        screen = screenName || focusedScreen();
        current = name;
        return true;
    }
    function close(name) { if (!name || name === current) current = ""; }
    function toggle(name, screenName) {
        const where = screenName || focusedScreen();
        if (current === name && screen === where) close();
        else open(name, where);
    }

    IpcHandler {
        target: "panel"
        function open(name: string): void { panels.open(name, ""); }
        function toggle(name: string): void { panels.toggle(name, ""); }
        function close(name: string): void { panels.close(name); }
        function list(): string { return Object.keys(panels.registry).sort().join("\n"); }
        function current(): string { return panels.current; }
    }
}
