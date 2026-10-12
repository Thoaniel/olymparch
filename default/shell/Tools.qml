pragma Singleton
// The everyday tools' state in the shell (olymparch-tool): which picker is open, and whether the screen is being
// recorded (the red dot in the bar). olymparch-tool talks to it with «qs ipc call tools …».
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: tools
    property bool clipboardOpen: false
    property bool emojiOpen: false
    property bool recording: false
    property date recordingSince: new Date()
    function stopRecording() { Quickshell.execDetached(["olymparch-tool", "record"]); }

    IpcHandler {
        target: "tools"
        function clipboard(): void { tools.emojiOpen = false; tools.clipboardOpen = !tools.clipboardOpen; }
        function emoji(): void { tools.clipboardOpen = false; tools.emojiOpen = !tools.emojiOpen; }
        function recording(on: bool): void {
            if (on && !tools.recording) tools.recordingSince = new Date();
            tools.recording = on;
        }
    }
    // a recording that was running when the shell (re)started
    Process {
        running: true
        command: ["sh", "-c", '[ -n "$XDG_RUNTIME_DIR" ] && read -r p _ < "$XDG_RUNTIME_DIR/olymparch-tool/recording" 2>/dev/null && kill -0 "$p" 2>/dev/null']
        onExited: code => tools.recording = code === 0
    }
}
