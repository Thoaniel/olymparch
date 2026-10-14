// The Power panel (under the battery, laptops): charge, time left or to full, the power profile (power-profiles-
// daemon: saver / balanced / performance) and the power settings.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Dropdown {
    id: p
    name: "power"
    icon: "\u{F0079}"
    title: t("power.title", "Power")
    en: "Power"
    nb: "Strøm"
    panelWidth: theme.px(400)
    function t(key, en) { return I18n.t(key, en); }
    readonly property var bat: UPower.displayDevice
    readonly property bool charging: bat && bat.state === UPowerDeviceState.Charging
    function hm(s) { s = Math.round(s / 60); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
    status: !bat || !bat.isLaptopBattery ? t("power.no_battery", "No battery")
          : Math.round(bat.percentage * 100) + " %  ·  " + (charging ? t("power.charging", "charging") + (bat.timeToFull > 0 ? ", " + t("power.full_in", "full in") + " " + hm(bat.timeToFull) : "")
                                                                 : (bat.timeToEmpty > 0 ? hm(bat.timeToEmpty) + " " + t("power.left", "left") : t("power.on_battery", "on battery")))
    property string profile: ""
    property bool hasProfiles: false
    onOpened: { get.running = false; get.running = true; }
    Process {
        id: get
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl get"]
        stdout: StdioCollector { onStreamFinished: { p.profile = text.trim(); p.hasProfiles = p.profile !== ""; } }
    }
    Process { id: set; onExited: { get.running = false; get.running = true; } }
    PanelLine { theme: p.theme; heading: true; visible: p.hasProfiles; label: p.t("power.profile", "Power profile") }
    Repeater {
        model: p.hasProfiles ? [["power-saver", p.t("power.saver", "Power saver")], ["balanced", p.t("power.balanced", "Balanced")], ["performance", p.t("power.performance", "Performance")]] : []
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: p.profile === modelData[0] ? "" : ""
            label: modelData[1]
            onActivated: { set.command = ["powerprofilesctl", "set", modelData[0]]; set.running = true; }
        }
    }
    PanelAction { theme: p.theme; icon: "\u{F04B2}"; label: p.t("power.sleep", "Sleep"); hint: p.t("power.sleep_hint", "open apps stay as they are"); onActivated: { Panels.close("power"); Quickshell.execDetached(["systemctl", "suspend"]); } }
    PanelAction { theme: p.theme; icon: ""; label: p.t("power.settings", "Power settings"); onActivated: { Panels.close("power"); Quickshell.execDetached(["olymparch-settings", "open", "power"]); } }
}
