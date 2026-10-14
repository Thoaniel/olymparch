// The System panel (under the clock): how the PC is doing right now — CPU, graphics card, memory and the
// temperatures as small live graphs (sampled every 1.5 s, only while the panel is open), what uses the most CPU (your
// own processes can be ended after a second click), the space on every disk, how long the PC has been on, game mode (on by itself in games, or by hand), do not disturb,
// and the health check (olymparch-doctor), updates waiting, Roll back and Settings. Data: /proc, /sys, ps, df, and
// olymparch-sysinfo --json for the health check and updates.
import QtQuick
import Quickshell
import Quickshell.Io

Dropdown {
    id: p
    name: "system"
    icon: ""
    title: t("system.title", "System")
    en: "System"
    nb: "System"
    panelWidth: theme.px(460)
    function t(key, en) { return I18n.t(key, en); }
    property var info: ({})
    property bool loading: false
    status: loading ? t("system.checking", "Checking …")
          : info.problems === undefined ? ""
          : info.problems === 0 ? t("system.ok", "Everything looks fine")
          : t("system.problems", "%1 problem(s) found").replace("%1", info.problems)
    statusTint: info.problems > 0 ? theme.red : theme.muted
    onOpened: {
        loading = true; confirmPid = "";
        probe.running = false; probe.running = true;
        gmState.running = false; gmState.running = true;
        SysStats.sample(); lists.running = false; lists.running = true;
    }

    // ── an update that needs a restart to finish: first in the panel, the second press restarts
    property bool restartSure: false
    PanelAction {
        theme: p.theme
        visible: RestartNeeded.needed
        icon: "\u{F0709}"
        danger: p.restartSure
        label: p.restartSure ? p.t("system.restart_sure", "Press again to restart now") : p.t("system.restart_needed", "Restart to finish the update")
        hint: p.restartSure ? "" : p.t("system.restart_why", "a new kernel or driver is installed")
        onActivated: { if (!p.restartSure) { p.restartSure = true; return; } Quickshell.execDetached(["systemctl", "reboot"]); }
    }

    // ── live numbers (SysStats, shared with the bar): sampled faster while this panel is open
    onVisibleChanged: { SysStats.fast = visible; if (!visible) restartSure = false; }
    function gb(bytes) { return SysStats.gb(bytes); }
    readonly property string uptime: {
        const t = SysStats.uptime, d = Math.floor(t / 86400), h = Math.floor(t % 86400 / 3600), m = Math.floor(t % 3600 / 60);
        return t ? (d ? d + " " + p.t("system.days", "d") + " " : "") + h + " " + p.t("system.hours", "h") + " " + m + " min" : "";
    }

    // a row: label, the number, and its graph on the right
    component Meter: Item {
        id: m
        property string label: ""
        property string value: ""
        property var values: []
        property real max: 100
        property real warn: 1e9
        width: p.panelWidth - 2
        height: p.theme.px(28)
        visible: values.length > 0
        readonly property bool hot: values.length > 0 && values[values.length - 1] >= warn
        Text { x: p.theme.px(18); width: p.theme.px(120); anchors.verticalCenter: parent.verticalCenter; text: m.label; elide: Text.ElideRight
               font { family: p.theme.mono; pixelSize: p.theme.px(13) } color: p.theme.muted }
        Text { anchors { right: graph.left; rightMargin: p.theme.px(10); verticalCenter: parent.verticalCenter } text: m.value
               font { family: p.theme.mono; pixelSize: p.theme.px(13) } color: m.hot ? p.theme.red : p.theme.text }
        Sparkline { id: graph; theme: p.theme; width: p.theme.px(120); height: p.theme.px(20); anchors { right: parent.right; rightMargin: p.theme.px(18); verticalCenter: parent.verticalCenter }
                    values: m.values; max: m.max; tint: m.hot ? p.theme.red : p.theme.gold }
    }
    Meter { label: p.t("system.cpu_use", "CPU"); values: SysStats.cpuH; value: SysStats.cpu + " %" }
    Meter { label: p.t("system.gpu_use", "Graphics card"); values: SysStats.gpuH; value: SysStats.gpu + " %" }
    PanelLine { theme: p.theme; visible: SysStats.vramTotal > 0; label: p.t("system.vram", "Graphics memory"); value: p.gb(SysStats.vramUsed) + " / " + p.gb(SysStats.vramTotal) + " GB" }
    Meter { label: p.t("system.memory", "Memory"); values: SysStats.memH; value: p.gb(SysStats.memUsed) + " / " + p.gb(SysStats.memTotal) + " GB"; warn: 90 }
    Meter { label: p.t("system.cpu_temp", "CPU temperature"); values: SysStats.cpuT; value: SysStats.cpuTemp + " °C"; max: 100; warn: 90 }
    Meter { label: p.t("system.gpu_temp", "GPU temperature"); values: SysStats.gpuT; value: SysStats.gpuTemp + " °C"; max: 110; warn: 95 }
    PanelLine { theme: p.theme; visible: p.uptime !== ""; label: p.t("system.uptime", "Uptime"); value: p.uptime }

    // ── what uses the most CPU, and the disks (read when the panel opens)
    property var procs: []            // [{ pid, user, cpu, mem, name }]
    property var disks: []            // [{ mount, size, used, pct }]
    property string confirmPid: ""
    readonly property string me: Quickshell.env("USER") || ""
    Process {
        id: lists
        command: ["sh", "-c", "ps -eo pid=,user:32=,pcpu=,rss=,comm= --sort=-pcpu | head -6 | sed 's/^/p /'; " +
                  "timeout 3 df -l -B1 --output=source,size,used,pcent,target -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | sed 's/^/d /'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pr = [], seen = {}, dk = [];
                for (const l of text.split("\n")) {
                    const f = l.trim().split(/\s+/);
                    if (f[0] === "p" && f.length >= 6) pr.push({ pid: f[1], user: f[2], cpu: Math.round(Number(f[3])), mem: Math.round(Number(f[4]) / 1024), name: f.slice(5).join(" ") });
                    else if (f[0] === "d" && f.length >= 6) {
                        // btrfs shows one line per subvolume: keep one per device, the shortest mount point
                        const d = { src: f[1], size: Number(f[2]), used: Number(f[3]), pct: parseInt(f[4]), mount: f.slice(5).join(" ") };
                        if (!seen[d.src] || d.mount.length < seen[d.src].mount.length) seen[d.src] = d;
                    }
                }
                for (const k in seen) dk.push(seen[k]);
                p.procs = pr; p.disks = dk.sort((a, b) => a.mount.localeCompare(b.mount));
            }
        }
    }
    Process { id: killer; onExited: { p.confirmPid = ""; lists.running = false; lists.running = true; } }

    PanelLine { theme: p.theme; heading: true; visible: p.procs.length > 0; label: p.t("system.top", "Using the most CPU") }
    Repeater {
        model: p.procs.slice(0, 5)
        delegate: PanelAction {
            required property var modelData
            readonly property bool mine: modelData.user === p.me && p.me !== ""
            theme: p.theme
            icon: "\u{F0156}"
            danger: p.confirmPid === modelData.pid
            enabledAction: mine
            label: modelData.name + (p.procs.filter(o => o.name === modelData.name).length > 1 ? "  #" + modelData.pid : "")
            hint: p.confirmPid === modelData.pid ? p.t("system.kill_sure", "Enter again ends it")
                  : String(modelData.cpu).padStart(3) + " %  " + String(modelData.mem).padStart(6) + " MB" + (mine ? "" : "  · " + modelData.user)
            onActivated: {
                if (!mine || !/^\d+$/.test(modelData.pid)) return;
                if (p.confirmPid !== modelData.pid) { p.confirmPid = modelData.pid; return; }
                killer.command = ["kill", modelData.pid]; killer.running = true;
            }
        }
    }

    PanelLine { theme: p.theme; heading: true; visible: p.disks.length > 0; label: p.t("system.disks", "Disks") }
    Repeater {
        model: p.disks
        delegate: PanelLine {
            required property var modelData
            theme: p.theme
            label: modelData.mount.startsWith("/run/media/") ? modelData.mount.split("/").pop() : modelData.mount
            value: p.t("system.disk_free", "%1 GB free of %2 GB · %3 % used").replace("%1", p.gb(modelData.size - modelData.used)).replace("%2", p.gb(modelData.size)).replace("%3", modelData.pct)
            valueTint: modelData.pct >= 90 ? p.theme.red : p.theme.text
        }
    }

    // ── the health check (olymparch-sysinfo) and the actions
    Process {
        id: probe
        command: ["olymparch-sysinfo", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { p.loading = false; try { p.info = JSON.parse(text.trim()) || {}; } catch (e) { p.info = {}; } }
        }
        onExited: code => { if (code !== 0) p.loading = false; }
    }
    PanelLine { theme: p.theme; heading: true; label: p.t("system.care", "Care") }
    PanelLine { theme: p.theme; visible: p.info.updates !== undefined && p.info.updates !== null; label: p.t("system.updates", "Updates"); value: p.info.updates > 0 ? String(p.info.updates) : p.t("system.none", "none") }
    // game mode (by hand; gamemoded switches it for games) and do not disturb
    property bool gaming: false
    Process {
        id: gmState
        command: ["qs", "ipc", "-p", "/usr/share/olymparch/shell", "call", "olymparch", "status"]
        stdout: StdioCollector { onStreamFinished: { try { p.gaming = !!JSON.parse(text.trim()).gamemode; } catch (e) {} } }
    }
    Process { id: gmSet; onExited: { gmState.running = false; gmState.running = true; } }
    PanelAction {
        theme: p.theme
        icon: "\u{F0297}"
        label: p.gaming ? p.t("system.gamemode_off", "Turn game mode off") : p.t("system.gamemode_on", "Game mode")
        hint: p.t("system.gamemode_hint", "local AI off, background jobs wait")
        onActivated: { gmSet.command = ["qs", "ipc", "-p", "/usr/share/olymparch/shell", "call", "olymparch", "gamemode", p.gaming ? "off" : "on"]; gmSet.running = true; }
    }
    PanelAction {   // do not disturb: the same switch as the bell (Settings → Notifications)
        theme: p.theme
        icon: p.theme.dndSetting ? "\u{F009B}" : "\u{F009A}"
        label: p.theme.dndSetting ? p.t("system.dnd_off", "Turn do not disturb off") : p.t("system.dnd_on", "Do not disturb")
        onActivated: p.theme.toggleDnd()
    }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.doctor", "Check the system"); hint: "olymparch-doctor"; onActivated: { Panels.close("system"); Quickshell.execDetached(["foot", "-H", "olymparch-doctor"]); } }
    PanelAction { theme: p.theme; visible: Updates.count > 0 || p.info.updates > 0; icon: ""; label: p.t("system.update", "Update now"); hint: Updates.count > 0 ? String(Updates.count) : ""; onActivated: { Panels.close("system"); Quickshell.execDetached(["qs", "ipc", "-p", "/usr/share/olymparch/shell", "call", "menu", "update"]); } }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.rollback", "Roll back to a snapshot"); onActivated: { Panels.close("system"); Quickshell.execDetached(["foot", "-e", "olymparch-rollback"]); } }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.settings", "All settings"); onActivated: { Panels.close("system"); Quickshell.execDetached(["olymparch-settings", "open"]); } }
}
