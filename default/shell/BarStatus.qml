// The right side of the bar: how the PC is doing (CPU, temperature, memory), what is playing, microphone/camera in
// use, Zeus, network, volume, battery (laptops only), notifications, updates waiting, the weather and the clock.
// Most of it follows events (PipeWire, MPRIS, NetworkManager, UPower); SysStats reads /proc every 3 s, Updates and
// Weather now and then.
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
    property string screenName: ""   // this bar's monitor: its panels open here
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

    // a thin line between groups of cells
    component Divider: Item {
        width: 13; height: 34
        Rectangle { anchors.centerIn: parent; width: 1; height: 16; color: status.theme.line }
    }
    component Cell: Item {
        id: cell
        property string icon
        property string label
        property color tint: status.theme.muted
        property color labelTint: status.theme.text
        property bool clickable: false
        property bool alert: false        // a solid red block (microphone, camera, battery nearly empty)
        property bool dot: false          // a small dot on the icon's corner: something waits for you
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
                Rectangle {
                    visible: cell.dot
                    width: 6; height: 6; radius: 3
                    color: status.theme.goldHi
                    x: parent.width - 2; y: -1
                }
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

    // ── the left side of the bar (shell.qml gives the place after the workspaces): how the PC is doing — CPU use,
    // the hottest temperature (graphics card, else CPU), memory in use, each with its own icon — and what is playing
    property Item leftSlot: null
    Row {
        id: leftGroup
        parent: status.leftSlot || status
        spacing: 4
        readonly property bool hotPc: SysStats.gpuTemp >= 95 || SysStats.cpuTemp >= 90
        Cell {
            id: sysCell
            icon: "\u{F061A}"
            label: SysStats.cpu + "%"
            labelChars: 4
            clickable: true
            onClicked: Panels.toggle("system", status.screenName)
        }
        Cell {
            readonly property int temp: SysStats.gpuTemp || SysStats.cpuTemp
            visible: temp > 0
            icon: "\u{F050F}"
            label: temp + "°C"
            labelChars: 5
            tint: leftGroup.hotPc ? status.theme.red : status.theme.muted
            labelTint: leftGroup.hotPc ? status.theme.red : status.theme.text
            clickable: true
            onClicked: Panels.toggle("system", status.screenName)
        }
        Cell {
            icon: "\u{F035B}"
            label: SysStats.gb(SysStats.memUsed) + " GB"
            labelChars: 7
            clickable: true
            onClicked: Panels.toggle("system", status.screenName)
        }
        Divider { visible: mediaCell.visible }
        Cell {
            id: mediaCell
            visible: status.player !== null
            icon: status.player && status.player.isPlaying ? "\u{F075A}" : "\u{F03E4}"
            label: status.player ? [status.player.trackArtist, status.player.trackTitle].filter(s => s).join(" – ") : ""
            clickable: true
            onClicked: Panels.toggle("media", status.screenName)   // play/pause, next … are in the panel
        }
    }
    MediaPanel { theme: status.theme; anchorItem: mediaCell.visible ? mediaCell : clockItem; screenName: status.screenName }
    // Settings → Privacy → «Camera and microphone indicator» can hide these two
    readonly property bool privacyIndicator: Settings.get("privacy.indicator") !== false
    Cell { id: micCell; visible: status.micInUse && status.privacyIndicator; icon: "\u{F036C}"; alert: true; clickable: true; onClicked: Panels.toggle("privacy", status.screenName) }
    Cell { id: camCell; visible: status.camInUse && status.privacyIndicator; icon: "\u{F0100}"; alert: true; clickable: true; onClicked: Panels.toggle("privacy", status.screenName) }
    PrivacyPanel { theme: status.theme; anchorItem: micCell.visible ? micCell : camCell.visible ? camCell : clockItem; screenName: status.screenName }
    // ── screen recording (olymparch-tool record, Super+Shift+R): red with the time; a click stops it
    Cell {
        id: recCell
        visible: Tools.recording
        icon: "\u{F04DB}"   // a square: stop
        property int secs: 0
        label: `${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, "0")}`
        labelChars: 5
        alert: true
        clickable: true
        onClicked: Panels.toggle("recording", status.screenName)   // Stop and the folder are in the panel
        Timer {
            running: Tools.recording
            interval: 1000; repeat: true; triggeredOnStart: true
            onTriggered: recCell.secs = Math.max(0, Math.round((Date.now() - Tools.recordingSince.getTime()) / 1000))
        }
    }
    RecordPanel { theme: status.theme; anchorItem: recCell.visible ? recCell : clockItem; screenName: status.screenName }
    // ── Zeus (Zeus.qml, `olympus bar`): what it is doing and who answers; a click opens its panel (ZeusPanel.qml)
    Divider { visible: micCell.visible || camCell.visible || recCell.visible }
    Cell {
        id: zeusCell
        visible: Zeus.enabled
        readonly property bool waiting: Zeus.state === "approval"
        readonly property bool off: !Zeus.connected || Zeus.ai === false
        icon: "\uf0e7"
        label: off ? I18n.t("zeus.bar.off", "Zeus off")
             : waiting ? I18n.t("zeus.bar.waiting", "Zeus · waiting")
             : Zeus.state === "thinking" ? I18n.t("zeus.bar.thinking", "Zeus · thinking")
             : Zeus.answeringCloud ? "Zeus · " + Zeus.answeringProvider : "Zeus"   // who answered, after a fallback too
        dot: waiting
        tint: off ? status.theme.muted : status.theme.gold
        labelTint: off ? status.theme.muted : waiting ? status.theme.goldHi : status.theme.text
        maxLabelWidth: status.theme.px(420)
        clickable: true
        onClicked: Panels.toggle("zeus", status.screenName)
        // thinking: the cell breathes; waiting for you: a gold dot on the bolt
        SequentialAnimation on opacity {
            running: Zeus.state === "thinking" && !zeusCell.off
            loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 700 }
            NumberAnimation { to: 1; duration: 700 }
            onStopped: zeusCell.opacity = 1
        }
    }
    ZeusPanel { theme: status.theme; anchorItem: zeusCell; screenName: status.screenName }
    // ── AI agents (Agents.qml, olymparch-agent): how many tasks run across every agent; a gold dot when one waits
    Cell {
        id: agentsCell
        visible: Agents.available && Agents.present && (Agents.tasks.length > 0 || Agents.list.some(a => a.installed))
        icon: "\u{F06A9}"
        label: Agents.active > 0 ? String(Agents.active) : ""
        dot: Agents.waiting
        tint: Agents.active > 0 ? status.theme.gold : status.theme.muted
        labelTint: Agents.waiting ? status.theme.goldHi : status.theme.text
        clickable: true
        onClicked: Panels.toggle("agents", status.screenName)
    }
    AgentsPanel { theme: status.theme; anchorItem: agentsCell; screenName: status.screenName }
    Divider {}
    Cell {
        id: netCell
        icon: !status.netDevice ? (status.hasWifi ? "\u{F092D}" : "\u{F0319}")
            : status.wifiStrength < 0 ? "\u{F0318}"
            : ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"][Math.min(3, Math.floor(status.wifiStrength * 4))]
        tint: status.netDevice ? status.theme.muted : status.theme.red
        clickable: true
        onClicked: Panels.toggle("network", status.screenName)
    }
    NetPanel { theme: status.theme; anchorItem: netCell; screenName: status.screenName }
    Cell {
        id: soundCell
        visible: status.sink && status.sink.audio
        readonly property bool muted: !status.sink || !status.sink.audio || status.sink.audio.muted
        readonly property real level: status.sink && status.sink.audio ? status.sink.audio.volume : 0
        icon: muted ? "\u{F0581}" : level < 0.34 ? "\u{F057F}" : level < 0.67 ? "\u{F0580}" : "\u{F057E}"
        label: `${Math.round(level * 100)}%`
        labelChars: 4
        labelTint: muted ? status.theme.muted : status.theme.text
        clickable: true
        onClicked: Panels.toggle("sound", status.screenName)   // mute, outputs and the microphone are in the panel
        onWheel: d => status.sink.audio.volume = Math.max(0, Math.min(1, status.sink.audio.volume + (d > 0 ? 0.05 : -0.05)))
    }
    SoundPanel { theme: status.theme; anchorItem: soundCell.visible ? soundCell : clockItem; screenName: status.screenName }
    Cell {
        id: batteryCell
        visible: status.hasBattery
        clickable: true
        onClicked: Panels.toggle("power", status.screenName)
        readonly property real pct: status.battery ? status.battery.percentage : 0
        readonly property bool charging: status.battery && status.battery.state === UPowerDeviceState.Charging
        icon: charging ? "\u{F0084}" : pct >= 0.95 ? "\u{F0079}" : String.fromCodePoint(0xF007A + Math.max(0, Math.floor(pct * 10) - 1))
        label: `${Math.round(pct * 100)}%`
        labelChars: 4
        tint: pct < 0.2 && !charging ? status.theme.red : status.theme.muted
        alert: pct < 0.1 && !charging
    }
    // ── phones paired with Zeus: the Devices panel (also from the menu, under the clock, when there is none)
    Cell {
        id: phoneCell
        visible: Zeus.enabled && (Zeus.phones || []).length > 0
        icon: "\u{F011C}"
        tint: (Zeus.phones || []).some(x => x.online) ? status.theme.gold : status.theme.muted
        clickable: true
        onClicked: Panels.toggle("devices", status.screenName)
    }
    DevicesPanel { theme: status.theme; anchorItem: phoneCell.visible ? phoneCell : clockItem; screenName: status.screenName }
    PowerPanel { theme: status.theme; anchorItem: batteryCell.visible ? batteryCell : clockItem; screenName: status.screenName }
    // the bell: notifications (do not disturb is in its panel); a gold dot for ones you have not seen
    Cell {
        id: bellCell
        dot: NotifyHistory.unseen > 0 && Panels.current !== "notifications"
        icon: status.theme.dndSetting ? "\u{F009B}" : "\u{F009A}"
        tint: status.theme.dndSetting ? status.theme.gold : status.theme.muted
        clickable: true
        onClicked: Panels.toggle("notifications", status.screenName)
    }
    NotificationsPanel { theme: status.theme; anchorItem: bellCell; screenName: status.screenName }
    // an update that needs a restart to finish (a new kernel or graphics driver): the System panel has the button
    Cell {
        id: restartCell
        visible: RestartNeeded.needed
        icon: "\u{F0709}"
        tint: status.theme.gold
        dot: true
        clickable: true
        onClicked: Panels.toggle("system", status.screenName)
    }
    // updates waiting (a number only when there are some) and the weather (when Settings has a place)
    Cell {
        id: updatesCell
        visible: Updates.count > 0
        icon: "\u{F01DA}"
        label: String(Updates.count)
        tint: status.theme.gold
        clickable: true
        onClicked: Panels.toggle("system", status.screenName)
    }
    Divider { visible: weatherCell.visible }
    Cell {
        id: weatherCell
        visible: !!Weather.now
        icon: Weather.icon
        label: Weather.now ? Weather.now.temp + "°" : ""
        clickable: true
        onClicked: Panels.toggle("plan", status.screenName)
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    // the clock opens the Plan panel
    Item {
        id: clockItem
        width: clockText.implicitWidth
        height: 34
        Text {
            id: clockText
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().toString(clock.date, status.clockFormat)
            leftPadding: 6
            font { family: status.theme.mono; pixelSize: status.theme.px(13) }
            color: clockMouse.containsMouse ? status.theme.goldHi : status.theme.text
        }
        MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Panels.toggle("plan", status.screenName) }
    }
    PlanPanel { theme: status.theme; anchorItem: clockItem; screenName: status.screenName }
    SystemPanel { theme: status.theme; anchorItem: sysCell; screenName: status.screenName }

}
