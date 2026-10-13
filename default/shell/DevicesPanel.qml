// The Devices panel: Bluetooth (on/off, the paired headsets, controllers and mice with their battery, connect or
// disconnect with a click, pair a new one in Settings), your phones paired with Zeus (online or when last seen),
// Tailscale (how the phone reaches the PC away from home), and «Pair a new phone»: a QR code for the Zeus app.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Dropdown {
    id: p
    name: "devices"
    icon: "\u{F011C}"
    title: t("devices.title", "Devices")
    en: "Devices"
    nb: "Enheter"
    panelWidth: theme.px(420)
    function t(key, en) { return I18n.t(key, en); }
    readonly property var phones: Zeus.phones || []
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevices: adapter ? adapter.devices.values.filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected - a.connected) || String(a.name).localeCompare(String(b.name))) : []
    readonly property int btOn: btDevices.filter(d => d.connected).length
    status: (btOn ? t("devices.bt_connected", "%1 connected over Bluetooth").replace("%1", btOn) + "  ·  " : "")
          + (!Zeus.enabled ? t("devices.no_zeus", "Phones pair with Zeus (Olympus), which is not installed")
          : phones.length === 0 ? t("devices.none", "No phone paired yet")
          : t("devices.count", "%1 phone(s)").replace("%1", phones.length))
    property var pairing: null          // { url, expires_in, qr_svg }
    property string pairError: ""
    property var tailscale: null        // { online, ip, name }
    onOpened: { pairing = null; pairError = ""; ts.running = false; ts.running = true; }

    function ago(t) {
        const s = Math.max(0, Date.now() / 1000 - Number(t || 0));
        return s < 120 ? p.t("devices.now", "just now") : s < 7200 ? Math.round(s / 60) + " min" : s < 172800 ? Math.round(s / 3600) + " " + p.t("system.hours", "h") : Math.round(s / 86400) + " " + p.t("system.days", "d");
    }
    // ── Bluetooth
    PanelLine { theme: p.theme; heading: true; visible: !!p.adapter; label: "Bluetooth" }
    PanelAction {
        theme: p.theme; visible: !!p.adapter
        icon: "\u{F00AF}"
        label: p.adapter && p.adapter.enabled ? p.t("devices.bt_off", "Turn Bluetooth off") : p.t("devices.bt_on", "Turn Bluetooth on")
        onActivated: p.adapter.enabled = !p.adapter.enabled
    }
    Repeater {
        model: p.adapter && p.adapter.enabled ? p.btDevices : []
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: modelData.connected ? "" : ""
            label: modelData.name || modelData.address
            hint: (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + " %  ·  " : "")
                  + (modelData.state === BluetoothDeviceState.Connecting ? p.t("devices.bt_connecting", "connecting …")
                     : modelData.connected ? p.t("devices.bt_disconnect", "disconnect") : p.t("devices.bt_connect", "connect"))
            onActivated: { if (modelData.connected) modelData.disconnect(); else modelData.connect(); }
        }
    }
    PanelAction {
        theme: p.theme; visible: !!(p.adapter && p.adapter.enabled)
        icon: ""
        label: p.t("devices.bt_pair", "Connect a new Bluetooth device")
        onActivated: { Panels.close("devices"); Quickshell.execDetached(["olymparch-settings", "open", "bluetooth"]); }
    }
    PanelLine { theme: p.theme; heading: true; visible: p.phones.length > 0 || Zeus.enabled; label: p.t("devices.phones", "Phones") }
    Repeater {
        model: p.phones
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            enabledAction: false
            icon: "\u{F011C}"
            label: modelData.name || "?"
            hint: modelData.online ? p.t("devices.online", "online") : p.t("devices.seen_ago", "seen %1 ago").replace("%1", p.ago(modelData.last_seen))
        }
    }
    PanelLine {
        theme: p.theme
        visible: p.tailscale !== null
        label: "Tailscale"
        value: p.tailscale ? (p.tailscale.online ? p.tailscale.ip : p.t("devices.ts_off", "off")) : ""
        valueTint: p.tailscale && p.tailscale.online ? p.theme.text : p.theme.muted
    }
    Process {
        id: ts
        command: ["sh", "-c", "command -v tailscale >/dev/null && tailscale status --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const self = d.Self || {};
                    p.tailscale = { online: !!self.Online, ip: (self.TailscaleIPs || [])[0] || "", name: self.HostName || "" };
                } catch (e) { p.tailscale = null; }
            }
        }
    }
    PanelAction {
        theme: p.theme
        visible: Zeus.enabled && Zeus.connected && p.pairing === null
        icon: "\u{F011C}"
        label: p.t("devices.pair", "Connect a new phone")
        hint: p.t("devices.pair_hint", "QR code for the Zeus app")
        onActivated: Zeus.pair(r => { if (r.ok && r.result) p.pairing = r.result; else p.pairError = r.error || p.t("devices.pair_failed", "No pairing code"); })
    }
    Column {
        visible: p.pairing !== null
        width: p.panelWidth - 2
        spacing: p.theme.px(6)
        Rectangle {   // the QR code: dark on a light square, whatever the theme, so a camera reads it
            visible: !!(p.pairing && p.pairing.qr_svg)
            anchors.horizontalCenter: parent.horizontalCenter
            width: p.theme.px(220); height: width
            color: "#ffffff"
            Image {
                anchors { fill: parent; margins: 10 }
                source: p.pairing && p.pairing.qr_svg ? "data:image/svg+xml;utf8," + encodeURIComponent(p.pairing.qr_svg) : ""
                fillMode: Image.PreserveAspectFit
                smooth: false
                sourceSize { width: 400; height: 400 }
            }
        }
        Text {
            x: p.theme.px(18); width: parent.width - 2 * x
            text: p.pairing ? (p.pairing.qr_svg ? p.t("devices.scan", "Scan it with the Zeus app (valid for 10 minutes).")
                                                : p.t("devices.link", "Open this in the Zeus app (valid for 10 minutes):") + "\n" + p.pairing.url) : ""
            wrapMode: Text.WrapAnywhere
            font { family: p.theme.mono; pixelSize: p.theme.px(12) }
            color: p.theme.muted
        }
    }
    Text {
        visible: p.pairError !== ""
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        text: p.pairError
        wrapMode: Text.Wrap
        font { family: p.theme.mono; pixelSize: p.theme.px(12) }
        color: p.theme.red
    }
}
