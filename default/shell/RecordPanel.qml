// The Recording panel (under the red square while the screen is recorded): how long, Stop, and the folder the
// recordings go to (olymparch-tool record).
import QtQuick
import Quickshell

Dropdown {
    id: p
    name: "recording"
    icon: "\u{F04DB}"
    title: t("rec.title", "Screen recording")
    en: "Screen recording"
    nb: "Skjermopptak"
    panelWidth: theme.px(380)
    function t(key, en) { return I18n.t(key, en); }
    property int secs: 0
    Timer { running: p.visible && Tools.recording; interval: 1000; repeat: true; triggeredOnStart: true
            onTriggered: p.secs = Math.max(0, Math.round((Date.now() - Tools.recordingSince.getTime()) / 1000)) }
    status: Tools.recording ? t("rec.running", "Recording") + "  ·  " + Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0")
                            : t("rec.stopped", "Not recording")
    statusTint: Tools.recording ? theme.red : theme.muted
    PanelAction { theme: p.theme; visible: Tools.recording; icon: "\u{F04DB}"; danger: true; label: p.t("rec.stop", "Stop and save"); hint: "Super+Shift+R"
                  onActivated: { Tools.stopRecording(); Panels.close("recording"); } }
    PanelAction { theme: p.theme; icon: ""; label: p.t("rec.folder", "Open the recordings folder")
                  onActivated: { Panels.close("recording"); Quickshell.execDetached(["sh", "-c", 'd=$(xdg-user-dir VIDEOS 2>/dev/null); exec xdg-open "${d:-$HOME/Videos}"']); } }
}
