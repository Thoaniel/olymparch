pragma Singleton
// How the PC is doing right now, for the bar's system cell and the System panel's graphs: CPU use, graphics card
// use and memory, memory in use, and the hottest CPU and GPU sensor, with the last 40 samples of each. One small
// read of /proc and /sys every 3 s (every 1.5 s while the System panel is open); nothing else runs.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: s
    readonly property int keep: 40
    property var cpuH: []; property var gpuH: []; property var memH: []; property var cpuT: []; property var gpuT: []
    property real memUsed: 0; property real memTotal: 0       // bytes
    property real vramUsed: 0; property real vramTotal: 0
    property int uptime: 0                                    // seconds
    property bool fast: false                                 // the System panel is open
    function last(a) { return a.length ? a[a.length - 1] : 0; }
    function gb(bytes) { return Number(bytes / 1073741824).toLocaleString(Qt.locale(), "f", 1); }
    readonly property int cpu: last(cpuH)
    readonly property int gpu: last(gpuH)
    readonly property int mem: last(memH)
    readonly property int cpuTemp: last(cpuT)
    readonly property int gpuTemp: last(gpuT)
    property real prevTotal: 0; property real prevIdle: 0
    function push(arr, v) { const a = arr.concat([v]); return a.length > keep ? a.slice(a.length - keep) : a; }
    function sample() { if (!live.running) live.running = true; }

    Timer { running: true; interval: s.fast ? 1500 : 3000; repeat: true; triggeredOnStart: true; onTriggered: s.sample() }
    Process {
        id: live
        command: ["sh", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; " +
            // the graphics card with the most VRAM (the dedicated one, not a Ryzen iGPU next to it)
            "best=; max=0; for c in /sys/class/drm/card*/device; do [ -r $c/gpu_busy_percent ] || continue; v=$(cat $c/mem_info_vram_total 2>/dev/null || echo 0); [ \"$v\" -gt \"$max\" ] 2>/dev/null && { max=$v; best=$c; }; [ -z \"$best\" ] && best=$c; done; " +
            "[ -n \"$best\" ] && echo gpu $(cat $best/gpu_busy_percent $best/mem_info_vram_used $best/mem_info_vram_total 2>/dev/null); " +
            // only the CPU and GPU sensors (never disks: reading drivetemp could keep a hard disk from spinning down)
            "for h in /sys/class/hwmon/hwmon*; do read -r n <$h/name 2>/dev/null || continue; case $n in amdgpu|nouveau|nvidia|xe|i915|k10temp|coretemp|zenpower|cpu_thermal|acpitz) ;; *) continue ;; esac; " +
            "for f in $h/temp*_input; do [ -r $f ] && read -r v <$f && echo t $n $v; done; done 2>/dev/null; " +
            "echo up $(cut -d' ' -f1 /proc/uptime)"]
        stdout: StdioCollector {
            onStreamFinished: {
                let total = 0, avail = 0, cpuMax = 0, gpuMax = 0;
                for (const l of text.split("\n")) {
                    const f = l.trim().split(/\s+/);
                    if (f[0] === "cpu") {
                        const n = f.slice(1).map(Number), idle = n[3] + (n[4] || 0), sum = n.reduce((a, b) => a + b, 0);
                        if (s.prevTotal > 0 && sum > s.prevTotal) s.cpuH = s.push(s.cpuH, Math.round(100 * (1 - (idle - s.prevIdle) / (sum - s.prevTotal))));
                        s.prevTotal = sum; s.prevIdle = idle;
                    } else if (f[0] === "MemTotal:") total = Number(f[1]) * 1024;
                    else if (f[0] === "MemAvailable:") avail = Number(f[1]) * 1024;
                    else if (f[0] === "gpu" && f.length >= 2) {
                        s.gpuH = s.push(s.gpuH, Number(f[1]));
                        if (f.length >= 4) { s.vramUsed = Number(f[2]); s.vramTotal = Number(f[3]); }
                    } else if (f[0] === "t" && f.length >= 3) {
                        const c = Number(f[2]) / 1000;
                        if (!(c > 0 && c < 130)) continue;
                        if (/^(amdgpu|nouveau|nvidia|xe|i915)/.test(f[1])) gpuMax = Math.max(gpuMax, c);
                        else if (/^(k10temp|coretemp|zenpower|cpu_thermal|acpitz)/.test(f[1])) cpuMax = Math.max(cpuMax, c);
                    } else if (f[0] === "up") s.uptime = Math.floor(Number(f[1]));
                }
                if (total > 0) { s.memUsed = total - avail; s.memTotal = total; s.memH = s.push(s.memH, Math.round(100 * (total - avail) / total)); }
                if (cpuMax > 0) s.cpuT = s.push(s.cpuT, Math.round(cpuMax));
                if (gpuMax > 0) s.gpuT = s.push(s.gpuT, Math.round(gpuMax));
            }
        }
    }
}
