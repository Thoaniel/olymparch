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
    property string clockFormat: "ddd d MMM  HH:mm"   // day and month in the session's language (shell.qml sets it)
    TextMetrics { id: digits; font { family: status.theme.mono; pixelSize: status.theme.px(13) } text: "0" }
    spacing: 4   // the cells have 6 px padding of their own: 16 px between icons

    // ---- what is playing: the first player that plays, else the first paused one with a title
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) || ps.find(p => p.trackTitle && p.playbackState === MprisPlaybackState.Paused) || null;
    }
    // ---- microphone and camera: a recording stream exists (an app that listens, not one that plays)
    // (PipeWire's "Stream/Input/Audio" is AudioInStream; the camera one is the same with Video for Audio)
    readonly property int videoInStream: (PwNodeType.AudioInStream & ~PwNodeType.Audio) | PwNodeType.Video
    // Level meters (pavucontrol, OBS, visualisers) read audio too, but are not someone listening: left out.
    // The camera is seen when it is used through PipeWire (portals, browsers on Wayland); an app that opens
    // /dev/video* directly is not.
    function listening(n) {
        const p = n.properties || {};
        return p["stream.monitor"] !== "true" && !String(p["media.name"] || "").includes("Peak detect");
    }
    readonly property bool micInUse: Pipewire.nodes.values.some(n => n.type === PwNodeType.AudioInStream && listening(n))
    readonly property bool camInUse: Pipewire.nodes.values.some(n => n.type === status.videoInStream)
    // ---- network: the first connected device
    readonly property var netDevice: Networking.devices.values.find(d => d.connected) || null
    readonly property real wifiStrength: {
        if (!netDevice || netDevice.type !== DeviceType.Wifi) return -1;
        const n = netDevice.networks.values.find(n => n.connected);
        if (!n) return 0;
        return n.signalStrength > 1 ? n.signalStrength / 100 : n.signalStrength;   // 0–1 (some backends say 0–100)
    }
    readonly property bool hasWifi: Networking.devices.values.some(d => d.type === DeviceType.Wifi)
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
        property color labelTint: status.theme.text
        property bool clickable: false
        property bool alert: false        // a solid red block (microphone, camera, battery nearly empty)
        property int labelChars: 0        // > 0: fixed width in characters, so changing numbers do not shift the bar
        property int maxLabelWidth: 200
        readonly property bool hot: hover.containsMouse && clickable
        signal clicked
        signal wheel(int delta)
        implicitWidth: cellRow.implicitWidth + (alert ? 16 : 12)
        implicitHeight: 34
        Rectangle {
            anchors.fill: parent
            visible: cell.alert || cell.hot
            color: cell.alert ? status.theme.red : status.theme.surface
            Rectangle {
                visible: cell.hot && !cell.alert
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 2; color: status.theme.gold
            }
        }
        Row {
            id: cellRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: cell.icon
                font { family: "Symbols Nerd Font Mono"; pixelSize: status.theme.px(15) }
                color: cell.alert ? status.theme.bg : cell.hot ? status.theme.goldHi : cell.tint
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: cell.label.length > 0
                text: cell.label
                font { family: status.theme.mono; pixelSize: status.theme.px(13) }
                color: cell.alert ? status.theme.bg : cell.hot ? status.theme.goldHi : cell.labelTint
                elide: Text.ElideRight
                horizontalAlignment: cell.labelChars > 0 ? Text.AlignRight : Text.AlignLeft
                width: cell.labelChars > 0 ? digits.advanceWidth * cell.labelChars : Math.min(implicitWidth, cell.maxLabelWidth)
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
    // Settings → Privacy → «Camera and microphone indicator» can hide these two
    readonly property bool privacyIndicator: Settings.get("privacy.indicator") !== false
    Cell { visible: status.micInUse && status.privacyIndicator; icon: "\u{F036C}"; alert: true }
    Cell { visible: status.camInUse && status.privacyIndicator; icon: "\u{F0100}"; alert: true }
    Cell {
        visible: zeusCheck.installed
        icon: ""
        label: "Zeus"
        tint: status.theme.gold
        clickable: true
        onClicked: Quickshell.execDetached(["sh", "-c", 'exec foot -e "$HOME/.local/bin/olympus" zeus'])
    }
    Cell {
        icon: !status.netDevice ? (status.hasWifi ? "\u{F092D}" : "\u{F0319}")
            : status.wifiStrength < 0 ? "\u{F0318}"
            : ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"][Math.min(3, Math.floor(status.wifiStrength * 4))]
        tint: status.netDevice ? status.theme.muted : status.theme.red
        clickable: true
        onClicked: Quickshell.execDetached(["foot", "-e", "nmtui"])
    }
    Cell {
        visible: status.sink && status.sink.audio
        readonly property bool muted: !status.sink || !status.sink.audio || status.sink.audio.muted
        readonly property real level: status.sink && status.sink.audio ? status.sink.audio.volume : 0
        icon: muted ? "\u{F0581}" : level < 0.34 ? "\u{F057F}" : level < 0.67 ? "\u{F0580}" : "\u{F057E}"
        label: `${Math.round(level * 100)}%`
        labelChars: 4
        labelTint: muted ? status.theme.muted : status.theme.text
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
        labelChars: 4
        tint: pct < 0.2 && !charging ? status.theme.red : status.theme.muted
        alert: pct < 0.1 && !charging
    }
    Cell {
        icon: status.theme.dndSetting ? "\u{F009B}" : "\u{F009A}"
        tint: status.theme.dndSetting ? status.theme.gold : status.theme.muted
        clickable: true
        onClicked: status.theme.toggleDnd()
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.locale().toString(clock.date, status.clockFormat)
        leftPadding: 6
        font { family: status.theme.mono; pixelSize: status.theme.px(13) }
        color: status.theme.text
    }

    // Zeus is optional: the module shows only when Olympus is installed for the user (checked once)
    Process {
        id: zeusCheck
        property bool installed: false
        command: ["sh", "-c", 'test -x "$HOME/.local/bin/olympus"']
        running: true
        onExited: code => installed = code === 0
    }
}
