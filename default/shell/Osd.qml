// Volume OSD: a gold pixel bar for 1.5 s whenever the default output's volume or mute changes.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

Scope {
    id: osd
    required property var theme
    property bool shown: false
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    PwObjectTracker { objects: [osd.sink] }
    Timer { id: hide; interval: 1500; onTriggered: osd.shown = false }
    function poke() { if (sink) { shown = true; hide.restart(); } }
    onVolumeChanged: poke()
    onMutedChanged: poke()

    PanelWindow {
        visible: osd.shown
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-osd"
        exclusionMode: ExclusionMode.Ignore
        anchors { bottom: true }
        margins { bottom: 90 }
        implicitWidth: 360
        implicitHeight: 48
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: osd.theme.surface
            border.color: osd.theme.line
            Row {
                anchors.centerIn: parent
                spacing: 12
                Text {
                    text: osd.muted ? "\u{f0581}" : "\u{f057e}"   // nf-md volume_off / volume_high
                    font { family: "Symbols Nerd Font Mono"; pixelSize: 18 }
                    color: osd.muted ? osd.theme.muted : osd.theme.gold
                    anchors.verticalCenter: parent.verticalCenter
                }
                Row {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 20
                        Rectangle {
                            required property int index
                            width: 9; height: 14
                            color: !osd.muted && index < Math.round(osd.volume * 20) ? osd.theme.gold : osd.theme.line
                        }
                    }
                }
                Text {
                    text: osd.muted ? I18n.t("osd.muted", "muted") : Math.round(osd.volume * 100) + "%"
                    font { family: osd.theme.mono; pixelSize: 14 }
                    color: osd.theme.text
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                }
            }
        }
    }
}
