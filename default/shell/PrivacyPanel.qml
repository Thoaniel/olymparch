// The Privacy panel (under the red microphone or camera): which apps listen or film right now, mute the microphone,
// and the privacy settings. From PipeWire: an app that opens /dev/video* itself is not seen (BarStatus says so too).
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Dropdown {
    id: p
    name: "privacy"
    icon: "\u{F036C}"
    title: t("privacy.title", "Microphone and camera")
    en: "Microphone and camera"
    nb: "Mikrofon og kamera"
    panelWidth: theme.px(420)
    function t(key, en) { return I18n.t(key, en); }
    readonly property int videoIn: (PwNodeType.AudioInStream & ~PwNodeType.Audio) | PwNodeType.Video
    function appOf(n) { const pr = n.properties || {}; return pr["application.name"] || pr["application.process.binary"] || pr["node.name"] || "?"; }
    readonly property var listening: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream && (n.properties || {})["stream.monitor"] !== "true")
    readonly property var filming: Pipewire.nodes.values.filter(n => n.type === videoIn)
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: p.source ? [p.source] : [] }
    status: listening.length + filming.length === 0 ? t("privacy.none", "Nothing is listening or filming") : t("privacy.some", "In use right now")

    PanelLine { theme: p.theme; heading: true; visible: p.listening.length > 0; label: p.t("privacy.mic", "Listening") }
    Repeater { model: p.listening; delegate: PanelLine { required property var modelData; theme: p.theme; label: p.appOf(modelData); value: p.t("privacy.microphone", "microphone"); valueTint: p.theme.red } }
    PanelLine { theme: p.theme; heading: true; visible: p.filming.length > 0; label: p.t("privacy.cam", "Filming") }
    Repeater { model: p.filming; delegate: PanelLine { required property var modelData; theme: p.theme; label: p.appOf(modelData); value: p.t("privacy.camera", "camera"); valueTint: p.theme.red } }
    PanelAction {
        theme: p.theme; visible: !!(p.source && p.source.audio)
        icon: p.source && p.source.audio && p.source.audio.muted ? "\u{F036D}" : "\u{F036C}"
        label: p.source && p.source.audio && p.source.audio.muted ? p.t("privacy.mic_on", "Microphone on") : p.t("privacy.mic_off", "Mute the microphone")
        onActivated: p.source.audio.muted = !p.source.audio.muted
    }
    PanelAction { theme: p.theme; icon: ""; label: p.t("privacy.settings", "Privacy settings"); onActivated: { Panels.close("privacy"); Quickshell.execDetached(["olymparch-settings", "open", "privacy"]); } }
}
