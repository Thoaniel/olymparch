// The System panel (under the clock): how the PC is doing right now — CPU, graphics card, memory and the
// temperatures as small live graphs (sampled every 1.5 s, only while the panel is open), what uses the most CPU (your
// own processes can be ended after a second click), the space on every disk, how long the PC has been on, do not disturb,
// and the health check (olymparch-doctor), updates waiting, Roll back and Settings. Data: /proc, /sys, ps, df, and
// olymparch-sysinfo --json for the health check and updates.
import QtQuick
import Quickshell
import Quickshell.Io

Dropdown {
    id: p
    name: "system"
    icon: ""
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
        cpuH = []; gpuH = []; memH = []; cpuT = []; gpuT = []; prevTotal = 0;
        probe.running = false; probe.running = true;
        gmState.running = false; gmState.running = true;
        sample(); lists.running = false; lists.running = true;
    }

    // ── live numbers: one small read of /proc and /sys every 1.5 s while the panel is open
    readonly property int keep: 40
    property var cpuH: []; property var gpuH: []; property var memH: []; property var cpuT: []; property var gpuT: []
    property real prevTotal: 0; property real prevIdle: 0
    property string memText: ""; property string vramText: ""; property string uptime: ""
    function push(arr, v) { const a = arr.concat([v]); return a.length > keep ? a.slice(a.length - keep) : a; }
    function last(a) { return a.length ? a[a.length - 1] : 0; }
    function gb(bytes) { return (bytes / 1073741824).toFixed(1); }
    function sample() { live.running = false; live.running = true; }
    Timer { running: p.visible; interval: 1500; repeat: true; onTriggered: p.sample() }
    Process {
        id: live
        command: ["sh", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; " +
            "for c in /sys/class/drm/card*/device; do [ -r $c/gpu_busy_percent ] && { echo gpu $(cat $c/gpu_busy_percent $c/mem_info_vram_used $c/mem_info_vram_total 2>/dev/null); break; }; done; " +
            "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); for f in $h/temp*_input; do [ -r $f ] && echo t $n $(cat $f); done; done 2>/dev/null; " +
            "echo up $(cut -d' ' -f1 /proc/uptime)"]
        stdout: StdioCollector {
            onStreamFinished: {
                let memTotal = 0, memAvail = 0, cpuMax = 0, gpuMax = 0;
                for (const l of text.split("\n")) {
                    const f = l.trim().split(/\s+/);
                    if (f[0] === "cpu") {
                        const n = f.slice(1).map(Number), idle = n[3] + (n[4] || 0), total = n.reduce((a, b) => a + b, 0);
                        if (p.prevTotal > 0 && total > p.prevTotal) p.cpuH = p.push(p.cpuH, Math.round(100 * (1 - (idle - p.prevIdle) / (total - p.prevTotal))));
                        p.prevTotal = total; p.prevIdle = idle;
                    } else if (f[0] === "MemTotal:") memTotal = Number(f[1]) * 1024;
                    else if (f[0] === "MemAvailable:") memAvail = Number(f[1]) * 1024;
                    else if (f[0] === "gpu" && f.length >= 2) {
                        p.gpuH = p.push(p.gpuH, Number(f[1]));
                        p.vramText = f.length >= 4 ? p.gb(Number(f[2])) + " / " + p.gb(Number(f[3])) + " GB" : "";
                    } else if (f[0] === "t" && f.length >= 3) {
                        const c = Number(f[2]) / 1000;
                        if (!(c > 0 && c < 130)) continue;
                        if (/^(amdgpu|nouveau|nvidia|xe|i915)/.test(f[1])) gpuMax = Math.max(gpuMax, c);
                        else if (/^(k10temp|coretemp|zenpower|cpu_thermal|acpitz)/.test(f[1])) cpuMax = Math.max(cpuMax, c);
                    } else if (f[0] === "up") {
                        const s = Math.floor(Number(f[1])), d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
                        p.uptime = (d ? d + " " + p.t("system.days", "d") + " " : "") + h + " h " + m + " min";
                    }
                }
                if (memTotal > 0) { p.memH = p.push(p.memH, Math.round(100 * (memTotal - memAvail) / memTotal)); p.memText = p.gb(memTotal - memAvail) + " / " + p.gb(memTotal) + " GB"; }
                if (cpuMax > 0) p.cpuT = p.push(p.cpuT, Math.round(cpuMax));
                if (gpuMax > 0) p.gpuT = p.push(p.gpuT, Math.round(gpuMax));
            }
        }
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
        Text { anchors { right: graph.left; rightMargin: 12; verticalCenter: parent.verticalCenter } text: m.value
               font { family: p.theme.mono; pixelSize: p.theme.px(13) } color: m.hot ? p.theme.red : p.theme.text }
        Sparkline { id: graph; theme: p.theme; anchors { right: parent.right; rightMargin: p.theme.px(18); verticalCenter: parent.verticalCenter }
                    values: m.values; max: m.max; tint: m.hot ? p.theme.red : p.theme.gold }
    }
    Meter { label: p.t("system.cpu_use", "CPU"); values: p.cpuH; value: p.last(p.cpuH) + " %" }
    Meter { label: p.t("system.gpu_use", "Graphics card"); values: p.gpuH; value: p.last(p.gpuH) + " %" + (p.vramText ? "  ·  " + p.vramText : "") }
    Meter { label: p.t("system.memory", "Memory"); values: p.memH; value: p.memText; warn: 90 }
    Meter { label: p.t("system.cpu_temp", "CPU temperature"); values: p.cpuT; value: p.last(p.cpuT) + " °C"; max: 100; warn: 90 }
    Meter { label: p.t("system.gpu_temp", "GPU temperature"); values: p.gpuT; value: p.last(p.gpuT) + " °C"; max: 110; warn: 95 }
    PanelLine { theme: p.theme; visible: p.uptime !== ""; label: p.t("system.uptime", "On for"); value: p.uptime }

    // ── what uses the most CPU, and the disks (read when the panel opens)
    property var procs: []            // [{ pid, user, cpu, mem, name }]
    property var disks: []            // [{ mount, size, used, pct }]
    property string confirmPid: ""
    readonly property string me: Quickshell.env("USER") || ""
    Process {
        id: lists
        command: ["sh", "-c", "ps -eo pid=,user:32=,pcpu=,rss=,comm= --sort=-pcpu | head -6 | sed 's/^/p /'; " +
                  "df -B1 --output=source,target,size,used,pcent -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | sed 's/^/d /'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pr = [], seen = {}, dk = [];
                for (const l of text.split("\n")) {
                    const f = l.trim().split(/\s+/);
                    if (f[0] === "p" && f.length >= 6) pr.push({ pid: f[1], user: f[2], cpu: Math.round(Number(f[3])), mem: Math.round(Number(f[4]) / 1024), name: f.slice(5).join(" ") });
                    else if (f[0] === "d" && f.length >= 6) {
                        // btrfs shows one line per subvolume: keep one per device, the shortest mount point
                        const d = { src: f[1], mount: f[2], size: Number(f[3]), used: Number(f[4]), pct: parseInt(f[5]) };
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
            icon: ""
            danger: p.confirmPid === modelData.pid
            enabledAction: mine
            label: modelData.name + "  " + modelData.cpu + " %  ·  " + modelData.mem + " MB"
            hint: !mine ? modelData.user : p.confirmPid === modelData.pid ? p.t("system.kill_sure", "again to end it") : p.t("system.kill", "end")
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
            label: modelData.mount
            value: p.gb(modelData.size - modelData.used) + " " + p.t("system.gb_free", "GB free of") + " " + p.gb(modelData.size) + "  (" + modelData.pct + " %)"
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
    // do not disturb by hand; game mode itself follows the games (gamemoded), so it is shown, not switched
    property bool dnd: false
    property bool gaming: false
    Process {
        id: gmState
        command: ["qs", "ipc", "-p", "/usr/share/olymparch/shell", "call", "olymparch", "status"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text.trim()); p.dnd = !!j.dnd; p.gaming = !!j.gamemode; } catch (e) {} } }
    }
    Process { id: gmSet; onExited: { gmState.running = false; gmState.running = true; } }
    PanelAction {
        theme: p.theme
        icon: p.dnd ? "\u{F009B}" : "\u{F009A}"
        label: p.dnd ? p.t("system.dnd_off", "Turn do not disturb off") : p.t("system.dnd_on", "Do not disturb")
        hint: p.gaming ? p.t("system.gaming", "a game is running") : p.t("system.gamemode_auto", "game mode: on by itself in games")
        onActivated: { gmSet.command = ["qs", "ipc", "-p", "/usr/share/olymparch/shell", "call", "olymparch", "dnd", p.dnd ? "off" : "on"]; gmSet.running = true; }
    }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.doctor", "Check the system"); hint: "olymparch-doctor"; onActivated: { Panels.close("system"); Quickshell.execDetached(["foot", "-H", "olymparch-doctor"]); } }
    PanelAction { theme: p.theme; visible: p.info.updates > 0; icon: ""; label: p.t("system.update", "Update now"); onActivated: { Panels.close("system"); Quickshell.execDetached(["foot", "-H", "olymparch", "update"]); } }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.rollback", "Roll back to a snapshot"); onActivated: { Panels.close("system"); Quickshell.execDetached(["foot", "-e", "olymparch-rollback"]); } }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.settings", "All settings"); onActivated: { Panels.close("system"); Quickshell.execDetached(["olymparch-settings", "open"]); } }
}
