// Laptops: below 20 % on battery the power profile goes to power saver, and back to what it was when the charger
// is in or the battery is above 20 % again. Desktops (no laptop battery) are never touched.
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Scope {
    readonly property var battery: UPower.displayDevice
    readonly property bool low: battery !== null && battery.isLaptopBattery && UPower.onBattery && battery.percentage < 0.2
    property int before: -1

    onLowChanged: {
        if (low) {
            before = PowerProfiles.profile;
            PowerProfiles.profile = PowerProfile.PowerSaver;
            Quickshell.execDetached(["notify-send", "-a", "Olymparch", I18n.t("power.saver", "Power saver is on"),
                I18n.t("power.saver.body", "The battery is below 20 %. It switches back when you plug in.")]);
        } else if (before >= 0) {
            PowerProfiles.profile = before;
            before = -1;
        }
    }
}
