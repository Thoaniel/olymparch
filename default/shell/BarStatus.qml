// The right side of the bar: what is playing, microphone/camera in use, Zeus, network, volume, battery (laptops
// only), do not disturb and the clock. Everything here follows events (PipeWire, MPRIS, NetworkManager, UPower);
// nothing polls.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Row {
    id: status
    required property var theme
    property string clockFormat: "ddd d. MMM  HH:mm"
    spacing: 16

    // ---- what is playing: the first player that plays, else the first paused one with a title
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) || ps.find(p => p.trackTitle && p.playbackState === MprisPlaybackState.Paused) || null;
    }
    // ---- microphone and camera: a recording stream exists (an app that listens, not one that plays)
    // (PipeWire's "Stream/Input/Audio" is AudioInStream; the camera one is the same with Video for Audio)
    readonly property int videoInStream: (PwNodeType.AudioInStream & ~PwNodeType.Audio) | PwNodeType.Video
    readonly property bool micInUse: Pipewire.nodes.values.some(n => n.type === PwNodeType.AudioInStream)
    readonly property bool camInUse: Pipewire.nodes.values.some(n => n.type === status.videoInStream)
    // ---- network: the first connected device
    readonly property var netDevice: Networking.devices.values.find(d => d.connected) || null
    readonly property real wifiStrength: {
        if (!netDevice || netDevice.type !== DeviceType.Wifi) return -1;
        const n = netDevice.networks.values.find(n => n.connected);
        return n ? n.signalStrength : 0;
    }
    // ---- volume of the default output
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: status.sink ? [status.sink] : [] }
    // ---- battery: laptops only
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery && battery.isPresent

    component Cell: Item {
        id: cell
        property string icon
        property string label
        property color tint: status.theme.muted
        property bool clickable: false
        signal clicked
        signal wheel(int delta)
        implicitWidth: cellRow.implicitWidth
        implicitHeight: 32
        Row {
            id: cellRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                text: cell.icon
                font { family: "Symbols Nerd Font Mono"; pixelSize: 15 }
                color: hover.containsMouse && cell.clickable ? status.theme.goldHi : cell.tint
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: text.length > 0
                text: cell.label
                font { family: status.theme.mono; pixelSize: 13 }
                color: hover.containsMouse && cell.clickable ? status.theme.goldHi : status.theme.text
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 260)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: cell.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: cell.clicked()
            onWheel: w => cell.wheel(w.angleDelta.y)
        }
    }

    Cell {
        visible: status.player !== null
        icon: status.player && status.player.isPlaying ? "\u{F075A}" : "\u{F03E4}"
        label: status.player ? [status.player.trackArtist, status.player.trackTitle].filter(s => s).join(" – ") : ""
        clickable: status.player && status.player.canTogglePlaying
        onClicked: status.player.togglePlaying()
    }
    Cell { visible: status.micInUse; icon: "\u{F036C}"; tint: status.theme.red }
    Cell { visible: status.camInUse; icon: "\u{F0100}"; tint: status.theme.red }
    Cell {
        visible: zeusCheck.installed
        icon: ""
        label: "Zeus"
        tint: status.theme.gold
        clickable: true
        onClicked: Quickshell.execDetached(["foot", "-e", "olympus", "zeus"])
    }
    Cell {
        icon: !status.netDevice ? "\u{F092E}"
            : status.wifiStrength < 0 ? "\u{F0200}"
            : ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"][Math.min(3, Math.floor(status.wifiStrength * 4))]
        tint: status.netDevice ? status.theme.muted : status.theme.red
        clickable: true
        onClicked: Quickshell.execDetached(["foot", "-e", "nmtui"])
    }
    Cell {
        visible: status.sink && status.sink.audio
        icon: status.sink && status.sink.audio && !status.sink.audio.muted ? "\u{F057E}" : "\u{F0581}"
        label: status.sink && status.sink.audio ? `${Math.round(status.sink.audio.volume * 100)}%` : ""
        clickable: true
        onClicked: status.sink.audio.muted = !status.sink.audio.muted
        onWheel: d => status.sink.audio.volume = Math.max(0, Math.min(1, status.sink.audio.volume + (d > 0 ? 0.05 : -0.05)))
    }
    Cell {
        visible: status.hasBattery
        readonly property real pct: status.battery ? status.battery.percentage : 0
        readonly property bool charging: status.battery && status.battery.state === UPowerDeviceState.Charging
        icon: charging ? "\u{F0084}" : pct >= 0.95 ? "\u{F0079}" : String.fromCodePoint(0xF007A + Math.max(0, Math.floor(pct * 10) - 1))
        label: `${Math.round(pct * 100)}%`
        tint: pct < 0.2 && !charging ? status.theme.red : status.theme.muted
    }
    Cell {
        icon: status.theme.manualDnd ? "\u{F009B}" : "\u{F009A}"
        tint: status.theme.manualDnd ? status.theme.gold : status.theme.muted
        clickable: true
        onClicked: status.theme.manualDnd = !status.theme.manualDnd
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, status.clockFormat)
        font { family: status.theme.mono; pixelSize: 13 }
        color: status.theme.text
    }

    // Zeus is optional: the module shows only when Olympus is installed (checked once)
    Process {
        id: zeusCheck
        property bool installed: false
        command: ["test", "-x", "/usr/bin/olympus"]
        running: true
        onExited: code => installed = code === 0
    }
}
