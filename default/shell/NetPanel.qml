// The Network panel (B4), under the network icon: the connection in use, Wi-Fi on/off, the Wi-Fi networks near
// you (a known one connects with a click; a new one asks its password in nmtui), and the network settings.
import QtQuick
import Quickshell
import Quickshell.Networking

Dropdown {
    id: p
    name: "network"
    icon: "\u{F0928}"
    title: t("net.title", "Network")
    en: "Network"
    nb: "Nett"
    panelWidth: theme.px(420)
    function t(key, en) { return I18n.t(key, en); }
    readonly property var dev: Networking.devices.values.find(d => d.connected) || null
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    function strength(n) { const s = n.signalStrength > 1 ? n.signalStrength / 100 : n.signalStrength; return Math.round(s * 100); }
    readonly property var networks: wifi ? wifi.networks.values.slice().sort((a, b) => b.signalStrength - a.signalStrength).slice(0, 8) : []
    status: !dev ? t("net.offline", "Not connected")
          : dev.type === DeviceType.Wifi ? t("net.wifi", "Wi-Fi") + ": " + ((dev.networks.values.find(n => n.connected) || {}).name || dev.name)
          : t("net.wired", "Cable") + ": " + dev.name

    PanelAction {
        theme: p.theme; visible: !!p.wifi
        icon: "\u{F05A9}"
        label: Networking.wifiEnabled ? p.t("net.wifi_off", "Turn Wi-Fi off") : p.t("net.wifi_on", "Turn Wi-Fi on")
        onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
    }
    PanelLine { theme: p.theme; heading: true; visible: p.networks.length > 0; label: p.t("net.nearby", "Wi-Fi near you") }
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
    PanelAction { theme: p.theme; icon: ""; label: p.t("net.settings", "Network and VPN settings"); onActivated: { Panels.close("network"); Quickshell.execDetached(["olymparch-settings", "open", "network"]); } }
}
