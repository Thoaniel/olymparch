// The Network panel (under the network icon): the connection in use with its address, how fast the internet answers
// (one ping when it opens), Wi-Fi on/off and the networks near you (a known one connects with a click; a new one asks
// its password in nmtui), your VPN connections (on/off), Tailscale (Settings' own switch), airplane mode, and the
// network settings.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Dropdown {
    id: p
    name: "network"
    icon: "\u{F0928}"
    title: t("net.title", "Network")
    en: "Network"
    nb: "Nett"
    panelWidth: theme.px(440)
    function t(key, en) { return I18n.t(key, en); }
    readonly property var dev: Networking.devices.values.find(d => d.connected) || null
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    function strength(n) { const s = n.signalStrength > 1 ? n.signalStrength / 100 : n.signalStrength; return Math.round(s * 100); }
    readonly property var networks: wifi ? wifi.networks.values.slice().sort((a, b) => b.signalStrength - a.signalStrength).slice(0, 8) : []
    status: !dev ? t("net.offline", "Not connected")
          : dev.type === DeviceType.Wifi ? t("net.wifi", "Wi-Fi") + ": " + ((dev.networks.values.find(n => n.connected) || {}).name || dev.name)
          : t("net.wired", "Cable") + ": " + dev.name
    statusTint: dev ? theme.muted : theme.red

    // read when the panel opens: the address, one ping, the VPN connections, Tailscale's state
    property string address: ""
    property string ping: ""
    property var vpns: []             // [{ name, active }]
    property string tailscale: ""     // on | off | "" (not installed)
    onOpened: { address = ""; ping = ""; info.running = false; info.running = true; pinger.running = false; pinger.running = true; }
    Process {
        id: info
        command: ["sh", "-c", "ip -4 -o addr show scope global 2>/dev/null | awk '{print \"ip \" $2 \" \" $4}'; " +
                  "nmcli -t -f NAME,TYPE,ACTIVE connection show 2>/dev/null | awk -F: '$2 ~ /vpn|wireguard/ {print \"vpn \" $3 \" \" $1}'; " +
                  "command -v tailscale >/dev/null && { systemctl is-active --quiet tailscaled && echo 'ts on' || echo 'ts off'; }; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = [];
                let ip = "", ts = "";
                for (const l of text.split("\n")) {
                    const f = l.split(" ");
                    if (f[0] === "ip" && !ip) ip = f[2].split("/")[0] + "  (" + f[1] + ")";
                    else if (f[0] === "vpn") v.push({ active: f[1] === "yes", name: f.slice(2).join(" ") });
                    else if (f[0] === "ts") ts = f[1];
                }
                p.address = ip; p.vpns = v; p.tailscale = ts;
            }
        }
    }
    Process {
        id: pinger
        command: ["sh", "-c", "ping -n -c 1 -W 2 1.1.1.1 2>/dev/null | sed -n 's/.*time=\\([0-9.]*\\) ms.*/\\1/p'"]
        stdout: StdioCollector { onStreamFinished: p.ping = text.trim() ? Math.round(Number(text.trim())) + " ms" : p.t("net.no_answer", "no answer") }
    }
    Process { id: act; onExited: { info.running = false; info.running = true; } }

    PanelLine { theme: p.theme; visible: p.address !== ""; label: p.t("net.address", "Address"); value: p.address }
    PanelLine { theme: p.theme; visible: p.ping !== ""; label: p.t("net.internet", "Internet"); value: p.ping
                valueTint: /ms$/.test(p.ping) ? (parseInt(p.ping) > 150 ? p.theme.gold : p.theme.text) : p.theme.red }

    PanelAction {
        theme: p.theme; visible: !!p.wifi
        icon: "\u{F05A9}"
        label: Networking.wifiEnabled ? p.t("net.wifi_off", "Turn Wi-Fi off") : p.t("net.wifi_on", "Turn Wi-Fi on")
        onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
    }
    PanelLine { theme: p.theme; heading: true; visible: Networking.wifiEnabled && p.networks.length > 0; label: p.t("net.nearby", "Wi-Fi near you") }
    Repeater {
        model: Networking.wifiEnabled ? p.networks : []
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: modelData.connected ? "" : ""
            label: modelData.name
            hint: p.strength(modelData) + " %" + (modelData.known ? "" : "  ·  " + p.t("net.new", "new"))
            onActivated: {
                if (modelData.connected) return;
                if (modelData.known) modelData.connect();
                else if (/^-/.test(modelData.name)) return;   // a name that would read as an option
                else { Panels.close("network"); Quickshell.execDetached(["foot", "-e", "nmtui", "connect", modelData.name]); }
            }
        }
    }

    PanelLine { theme: p.theme; heading: true; visible: p.vpns.length > 0 || p.tailscale !== ""; label: p.t("net.vpn", "VPN") }
    Repeater {
        model: p.vpns
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: modelData.active ? "" : ""
            label: modelData.name
            hint: modelData.active ? p.t("net.vpn_off", "disconnect") : p.t("net.vpn_on", "connect")
            onActivated: { if (/^-/.test(modelData.name)) return; act.command = ["nmcli", "connection", modelData.active ? "down" : "up", "id", modelData.name]; act.running = true; }
        }
    }
    PanelAction {
        theme: p.theme; visible: p.tailscale !== ""
        icon: p.tailscale === "on" ? "" : ""
        label: "Tailscale"
        hint: p.tailscale === "on" ? p.t("net.on", "on") : p.t("net.off", "off")
        onActivated: { act.command = ["olymparch-settings", "set", "network.tailscale", p.tailscale === "on" ? "off" : "on"]; act.running = true; }
    }

    PanelAction {
        theme: p.theme
        icon: "\u{F001D}"
        label: Networking.wifiEnabled ? p.t("net.airplane_on", "Airplane mode (Wi-Fi and Bluetooth off)") : p.t("net.airplane_off", "Airplane mode off")
        onActivated: {
            const on = Networking.wifiEnabled;
            Networking.wifiEnabled = !on;
            act.command = ["sh", "-c", on ? "command -v bluetoothctl >/dev/null && bluetoothctl power off; true" : "command -v bluetoothctl >/dev/null && bluetoothctl power on; true"];
            act.running = true;
        }
    }
    PanelAction { theme: p.theme; icon: ""; label: p.t("net.settings", "Network and VPN settings"); onActivated: { Panels.close("network"); Quickshell.execDetached(["olymparch-settings", "open", "network"]); } }
}
