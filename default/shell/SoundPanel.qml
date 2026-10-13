// The Sound panel (under the volume): the volume as a slider and mute; every app that plays, with its own volume;
// where the sound goes (every output, one click switches); the microphone: its volume, mute, and which one is used.
// The wheel on the bar item still turns the volume. Everything through PipeWire (Quickshell.Services.Pipewire).
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
    panelWidth: theme.px(460)
    function t(key, en) { return I18n.t(key, en); }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !String(n.name || "").endsWith(".monitor"))
    readonly property var apps: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream && n.audio)
    PwObjectTracker { objects: p.sinks.concat(p.sources, p.apps) }
    function nameOf(n) { return n ? (n.description || n.nickname || n.name || "") : ""; }
    function appOf(n) { const pr = n.properties || {}; return pr["application.name"] || pr["media.name"] || n.name || "?"; }
    status: sink ? nameOf(sink) : t("sound.none", "No sound output")

    PanelSlider {
        theme: p.theme
        visible: !!(p.sink && p.sink.audio)
        label: p.t("sound.volume", "Volume")
        value: p.sink && p.sink.audio ? p.sink.audio.volume : 0
        maximum: 1
        muted: !!(p.sink && p.sink.audio && p.sink.audio.muted)
        valueText: muted ? p.t("sound.muted", "muted") : Math.round(value * 100) + " %"
        onMoved: v => { p.sink.audio.volume = v; if (v > 0) p.sink.audio.muted = false; }
    }
    PanelAction {
        theme: p.theme; visible: !!(p.sink && p.sink.audio)
        icon: p.sink && p.sink.audio && p.sink.audio.muted ? "\u{F057E}" : "\u{F0581}"
        label: p.sink && p.sink.audio && p.sink.audio.muted ? p.t("sound.unmute", "Sound on") : p.t("sound.mute", "Mute")
        onActivated: p.sink.audio.muted = !p.sink.audio.muted
    }

    PanelLine { theme: p.theme; heading: true; visible: p.apps.length > 0; label: p.t("sound.apps", "Apps playing") }
    Repeater {
        model: p.apps
        delegate: PanelSlider {
            required property var modelData
            theme: p.theme
            label: p.appOf(modelData)
            value: modelData.audio ? modelData.audio.volume : 0
            maximum: 1.5
            muted: !!(modelData.audio && modelData.audio.muted)
            onMoved: v => modelData.audio.volume = v
        }
    }

    PanelLine { theme: p.theme; heading: true; visible: p.sinks.length > 0; label: p.t("sound.outputs", "Play through") }
    Repeater {
        model: p.sinks
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: modelData === p.sink ? "" : ""
            label: p.nameOf(modelData)
            onActivated: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    PanelLine { theme: p.theme; heading: true; visible: !!p.source; label: p.t("sound.mic", "Microphone") }
    PanelSlider {
        theme: p.theme
        visible: !!(p.source && p.source.audio)
        label: p.t("sound.mic_level", "Level")
        value: p.source && p.source.audio ? p.source.audio.volume : 0
        muted: !!(p.source && p.source.audio && p.source.audio.muted)
        valueText: muted ? p.t("sound.muted", "muted") : Math.round(value * 100) + " %"
        onMoved: v => p.source.audio.volume = v
    }
    PanelAction {
        theme: p.theme; visible: !!(p.source && p.source.audio)
        icon: p.source && p.source.audio && p.source.audio.muted ? "\u{F036D}" : "\u{F036C}"
        label: p.source && p.source.audio && p.source.audio.muted ? p.t("sound.mic_on", "Microphone on") : p.t("sound.mic_off", "Microphone off")
        onActivated: p.source.audio.muted = !p.source.audio.muted
    }
    Repeater {
        model: p.sources.length > 1 ? p.sources : []
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: modelData === p.source ? "" : ""
            label: p.nameOf(modelData)
            onActivated: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
    PanelAction { theme: p.theme; icon: ""; label: p.t("sound.settings", "Sound settings"); onActivated: { Panels.close("sound"); Quickshell.execDetached(["olymparch-settings", "open", "audio"]); } }
}
