// The password prompt (polkit agent) for the session: when something asks for an admin's password through polkit
// (the menu's Install → Package and Remove, pkexec, Settings rows that change the system), this asks for it, in
// the shell's own look, over everything. Enter answers, Esc cancels. A wrong password says so and asks again
// (after three wrong ones in a row PAM locks the account for a while: pam_faillock).
// The shell is the agent (Quickshell.Services.Polkit), so no separate agent program is needed: one that draws
// with the GPU (hyprpolkitagent) cannot open its window without 3D acceleration, this one always can.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

Scope {
    id: auth
    required property var theme
    readonly property string lang: I18n.lang
    function t(en, nb) { return lang === "nb" ? nb : en; }
    readonly property var flow: agent.flow
    readonly property bool showing: agent.isActive && flow !== null && !flow.isCompleted
    property bool wrong: false   // the last answer was wrong

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: { auth.wrong = false; field.text = ""; }
    }
    Connections {
        target: auth.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() { auth.wrong = true; field.text = ""; }
        function onIsResponseRequiredChanged() { if (auth.flow && auth.flow.isResponseRequired) field.forceActiveFocus(); }
    }


    PanelWindow {
        visible: auth.showing
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-polkit"
        WlrLayershell.keyboardFocus: auth.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "#b3000000"   // the desktop dimmed: this needs an answer

        Rectangle {
            id: panel
            width: Math.min(parent.width - 32, auth.theme.px(480))
            height: col.implicitHeight + foot.height + 34
            anchors.centerIn: parent
            color: auth.theme.surface
            border.color: auth.theme.line
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: auth.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: auth.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: auth.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: auth.theme.gold }

            Column {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 12
                Row {
                    spacing: 8
                    Text { text: ""; font { family: "Symbols Nerd Font Mono"; pixelSize: auth.theme.px(14) } color: auth.theme.gold; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: auth.t("PASSWORD", "PASSORD")
                        font { family: auth.theme.mono; pixelSize: auth.theme.px(12); bold: true; letterSpacing: 2 }
                        color: auth.theme.gold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: auth.flow ? auth.flow.message : ""
                    font { family: auth.theme.mono; pixelSize: auth.theme.px(14) }
                    color: auth.theme.text
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: !!(auth.flow && auth.flow.actionId)
                    text: auth.flow ? auth.flow.actionId : ""
                    font { family: auth.theme.mono; pixelSize: auth.theme.px(11) }
                    color: auth.theme.muted
                }
                Rectangle {
                    width: parent.width
                    height: auth.theme.px(34)
                    color: "#0d0d12"
                    border.color: auth.wrong ? auth.theme.red : field.activeFocus ? auth.theme.gold : auth.theme.line
                    TextInput {
                        id: field
                        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        font { family: auth.theme.mono; pixelSize: auth.theme.px(14) }
                        color: auth.theme.goldHi
                        echoMode: auth.flow && auth.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "■"
                        clip: true
                        focus: auth.showing
                        enabled: !!(auth.flow && auth.flow.isResponseRequired)
                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_Escape) { if (auth.flow) auth.flow.cancelAuthenticationRequest(); }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                if (auth.flow && auth.flow.isResponseRequired) { auth.wrong = false; auth.flow.submit(text); text = ""; }
                            } else return;
                            e.accepted = true;
                        }
                        Text {
                            visible: !field.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: auth.flow && auth.flow.isResponseRequired ? auth.t("Your password", "Passordet ditt") : auth.t("Checking …", "Sjekker …")
                            font: field.font
                            color: auth.theme.muted
                        }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: auth.wrong || !!(auth.flow && auth.flow.supplementaryMessage)
                    text: auth.wrong ? auth.t("Wrong password. Try again, or Esc to cancel.", "Feil passord. Prøv igjen, eller Esc for å avbryte.")
                                     : (auth.flow ? auth.flow.supplementaryMessage : "")
                    font { family: auth.theme.mono; pixelSize: auth.theme.px(12) }
                    color: auth.wrong || (auth.flow && auth.flow.supplementaryIsError) ? auth.theme.red : auth.theme.muted
                }
            }
            Rectangle {
                id: foot
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                height: auth.theme.px(26)
                color: auth.theme.bg
                Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: auth.theme.line }
                Text {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: auth.t("⏎  ok     esc  cancel", "⏎  ok     esc  avbryt")
                    font { family: auth.theme.mono; pixelSize: auth.theme.px(11) }
                    color: auth.theme.muted
                }
            }
        }
    }
}
