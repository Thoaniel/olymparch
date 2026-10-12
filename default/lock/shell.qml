//@ pragma ShellId olymparch-lock
// The Olymparch lock screen, a small process of its own so a crash in the bar can never touch the lock.
// Still temple wallpaper (no animation), a clock, and the same password box as the boot screen.
// Started by olymparch-lock (Super+L, hypridle). Exits when unlocked.
// Settings → Account and lock → «The lock screen shows» (account.lock_shows) can hide the clock; it reads
// ~/.config/olymparch/settings.json itself (no Settings singleton here), and anything unknown shows the clock.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root
    // ── Theme: the active theme's colours and still wallpaper, from the checked copy olymparch-theme writes
    //    (~/.config/olymparch/theme/theme.json); Zeus' black and gold when it is missing. See docs/themes.md.
    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/olymparch/theme/theme.json"
        blockLoading: true
        printErrors: false
    }
    readonly property var themeData: { try { return JSON.parse(themeFile.text() || "{}") || {}; } catch (e) { return {}; } }
    function themeColour(k, zeus) {
        const v = (themeData.palette || {})[k];
        return /^#[0-9a-fA-F]{6}$/.test(v || "") ? v : zeus;
    }
    readonly property bool light: themeData.light === true
    readonly property color bg: themeColour("bg", "#0a0a0e")
    readonly property color gold: themeColour("accent", "#d4a73a")
    readonly property color goldHi: themeColour("accentHi", "#f4d35e")
    readonly property color text: themeColour("text", "#e8e6df")
    readonly property color muted: themeColour("muted", "#9a96a3")
    readonly property color line: themeColour("line", "#3a3644")
    readonly property color red: themeColour("danger", "#e0605e")
    readonly property color field: Qt.tint(bg, Qt.rgba(1, 1, 1, light ? 0 : 0.02))
    readonly property string art: /^\/[^\0]*$/.test(themeData.wallpaper || "") && (themeData.wallpaper || "").indexOf("..") < 0 ? themeData.wallpaper : "/usr/share/olymparch/wallpaper"
    readonly property bool has1440: !themeData.sets || themeData.sets.indexOf("1440") >= 0
    // ── end Theme
    readonly property string mono: "JetBrains Mono"
    property string password: ""
    property bool checking: false
    property bool failed: false
    readonly property bool showClock: setting("account.lock_shows") !== "nothing"

    FileView {
        id: settingsFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/olymparch/settings.json"
        blockLoading: true
        printErrors: false
    }
    function setting(key) {
        try { return (JSON.parse(settingsFile.text() || "{}") || {})[key]; } catch (e) { return undefined; }
    }

    PamContext {
        id: pam
        config: "olymparch-lock"
        onPamMessage: if (responseRequired) respond(root.password)
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                lock.locked = false;
                Qt.quit();
            } else {
                root.password = "";
                root.failed = true;
                shake.restart();
            }
        }
    }

    function submit() {
        if (checking || password.length === 0) return;
        failed = false;
        checking = true;
        pam.start();
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            color: root.light ? root.bg : Qt.darker(root.bg, 1.25)

            Image {
                anchors.fill: parent
                source: `file://${root.art}/${parent.height >= 1300 && root.has1440 ? "1440" : "1080"}/frame-00.png`
                fillMode: Image.PreserveAspectCrop
                smooth: false
            }

            SystemClock { id: clock; precision: SystemClock.Minutes }
            Column {
                visible: root.showClock
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.16
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font { family: root.mono; pixelSize: 96; bold: true }
                    color: root.gold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd d. MMMM").toUpperCase()
                    font { family: root.mono; pixelSize: 16; letterSpacing: 4 }
                    color: root.muted
                }
            }

            // Password: lock icon and a box with one gold square per character
            Item {
                id: box
                width: 340; height: 44
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.78
                Text {
                    anchors { right: frame.left; rightMargin: 12; verticalCenter: frame.verticalCenter }
                    text: "\u{f033e}"
                    font { family: "Symbols Nerd Font Mono"; pixelSize: 22 }
                    color: root.failed ? root.red : root.gold
                }
                Rectangle {
                    id: frame
                    anchors.fill: parent
                    color: root.field
                    border.color: root.failed ? root.red : root.line
                    Rectangle { x: -1; y: -1; width: 12; height: 2; color: root.gold }
                    Rectangle { x: -1; y: -1; width: 2; height: 12; color: root.gold }
                    Rectangle { x: parent.width - 11; y: parent.height - 1; width: 12; height: 2; color: root.gold }
                    Rectangle { x: parent.width - 1; y: parent.height - 11; width: 2; height: 12; color: root.gold }
                    Row {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Repeater {
                            model: Math.min(root.password.length, 24)
                            Rectangle { width: 8; height: 8; color: root.checking ? root.goldHi : root.gold }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.password.length === 0
                        text: root.failed ? "Feil passord" : ""
                        font { family: root.mono; pixelSize: 13 }
                        color: root.red
                    }
                }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 10; duration: 40 }
                    NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -10; duration: 80 }
                    NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 6; duration: 70 }
                    NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
                }
            }

            // Invisible input that owns the keyboard
            TextInput {
                focus: true
                width: 0; height: 0
                echoMode: TextInput.NoEcho
                onTextChanged: { if (!root.checking) root.password = text; if (text.length) root.failed = false; }
                Keys.onReturnPressed: { root.submit(); text = ""; }
                Keys.onEnterPressed: { root.submit(); text = ""; }
                Keys.onEscapePressed: { text = ""; root.password = ""; }
            }
        }
    }
}
