pragma Singleton
// Does an update need a restart to finish? Yes when the pacman hook zzz-olymparch-restart.hook marked one (a new
// kernel, graphics driver, systemd, glibc or mesa: /run/olymparch/restart-needed, gone after the restart), or when
// the running kernel's modules are no longer on disk (USB sticks, controllers and Wi-Fi after sleep would fail until
// a restart). The bar shows a restart sign, and the System panel a «Restart to finish the update» button.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: r
    property bool marked: false
    property bool modulesGone: false
    readonly property bool needed: marked || modulesGone
    function check() { if (!probe.running) probe.running = true; }
    Process {
        id: probe
        command: ["sh", "-c", "[ -e /run/olymparch/restart-needed ] && echo marked; [ -d \"/usr/lib/modules/$(uname -r)\" ] || echo modules"]
        stdout: StdioCollector {
            onStreamFinished: { r.marked = text.includes("marked"); r.modulesGone = text.includes("modules"); }
        }
    }
    // after every package change the hook writes the mark; a check every two minutes is plenty
    Timer { running: true; interval: 120000; repeat: true; triggeredOnStart: true; onTriggered: r.check() }
}
