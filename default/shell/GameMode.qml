// Spillmodus: while a game runs the bar hides and notifications stay quiet (do not disturb).
// gamemoded's start/end hooks switch it through IPC (olymparch-game-hook):
//   qs ipc -p /usr/share/olymparch/shell call olymparch gamemode on|off|toggle
//   qs ipc -p /usr/share/olymparch/shell call olymparch dnd on|off|toggle
//   qs ipc -p /usr/share/olymparch/shell call olymparch status       → {"gamemode":true,"dnd":true}
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: gm
    property bool active: false        // a game is running
    property bool manualDnd: false     // do not disturb switched on by hand
    readonly property bool dnd: active || manualDnd

    function parse(state, current) {
        return state === "toggle" ? !current : (state === "on" || state === "1" || state === "true");
    }

    IpcHandler {
        target: "olymparch"
        function gamemode(state: string): string {
            gm.active = gm.parse(state, gm.active);
            return gm.active ? "on" : "off";
        }
        function dnd(state: string): string {
            gm.manualDnd = gm.parse(state, gm.manualDnd);
            return gm.dnd ? "on" : "off";
        }
        function status(): string {
            return JSON.stringify({ gamemode: gm.active, dnd: gm.dnd });
        }
    }

    // A shell restarted in the middle of a game picks the state up from gamemoded itself
    Process {
        running: true
        command: ["sh", "-c", "command -v gamemoded >/dev/null && exec gamemoded -s"]   // no games option: nothing to ask
        stdout: StdioCollector {
            onStreamFinished: if (text.indexOf("is active") >= 0) gm.active = true
        }
    }
}
