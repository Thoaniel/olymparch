// The Sound panel (B4), under the volume: the output in use and the others to switch to (PipeWire), the volume in
// steps of 10, mute, and the microphone's mute. The wheel on the bar item still turns the volume.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Dropdown {
    id: p
    name: "sound"
    icon: "\u{F057E}"
    title: t("sound.title", "Sound")
    en: "Sound"
    nb: "Lyd"
    panelWidth: theme.px(420)
    function t(key, en) { return I18n.t(key, en); }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    PwObjectTracker { objects: p.sinks.concat(p.source ? [p.source] : []) }
    function nameOf(n) { return n ? (n.description || n.nickname || n.name || "") : ""; }
    readonly property real level: sink && sink.audio ? sink.audio.volume : 0
    status: sink ? nameOf(sink) + "  ·  " + (sink.audio && sink.audio.muted ? t("sound.muted", "muted") : Math.round(level * 100) + " %")
                 : t("sound.none", "No sound output")

    PanelAction {
        theme: p.theme; visible: !!(p.sink && p.sink.audio)
        icon: "\u{F057E}"; label: p.t("sound.up", "Louder"); hint: "+10 %"
        onActivated: p.sink.audio.volume = Math.min(1, p.sink.audio.volume + 0.1)
    }
    PanelAction {
        theme: p.theme; visible: !!(p.sink && p.sink.audio)
        icon: "\u{F057F}"; label: p.t("sound.down", "Quieter"); hint: "−10 %"
        onActivated: p.sink.audio.volume = Math.max(0, p.sink.audio.volume - 0.1)
    }
    PanelAction {
        theme: p.theme; visible: !!(p.sink && p.sink.audio)
        icon: "\u{F0581}"
        label: p.sink && p.sink.audio && p.sink.audio.muted ? p.t("sound.unmute", "Sound on") : p.t("sound.mute", "Mute")
        onActivated: p.sink.audio.muted = !p.sink.audio.muted
    }
    PanelAction {
        theme: p.theme; visible: !!(p.source && p.source.audio)
        icon: p.source && p.source.audio && p.source.audio.muted ? "\u{F036D}" : "\u{F036C}"
        label: p.source && p.source.audio && p.source.audio.muted ? p.t("sound.mic_on", "Microphone on") : p.t("sound.mic_off", "Microphone off")
        hint: p.nameOf(p.source)
        onActivated: p.source.audio.muted = !p.source.audio.muted
    }
    PanelLine { theme: p.theme; heading: true; visible: p.sinks.length > 1; label: p.t("sound.outputs", "Play through") }
    Repeater {
        model: p.sinks.length > 1 ? p.sinks : []
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: modelData === p.sink ? "" : ""
            label: p.nameOf(modelData)
            onActivated: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
    PanelAction { theme: p.theme; icon: ""; label: p.t("sound.settings", "Sound settings"); onActivated: { Panels.close("sound"); Quickshell.execDetached(["olymparch-settings", "open", "audio"]); } }
}
