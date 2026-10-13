// A dropdown panel under a bar item (B1): the frame every bar panel uses. At most one is open (Panels.qml holds
// which), on the monitor it was opened from; the bar item, the menu's «Panels» level, a hotkey and
// `qs ipc call panel toggle NAME` all open the same one. Click outside (Hyprland's focus grab) or Esc closes it.
// Calm on purpose: a heading, a status line, a few lines and clear actions (PanelAction) — no boxes in boxes.
// Keyboard like the menu: ↑/↓ (and Tab) move between actions, Enter or Space chooses, Esc closes.
//   Dropdown { name: "zeus"; anchorItem: zeusCell; screenName: modelData.name; theme: root
//              icon: ""; title: "Zeus"; status: "Idle · gemma4"
//              PanelAction { label: "Turn AI off"; onActivated: … } }
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: dd
    required property var theme
    required property string name        // Panels.registry key
    required property Item anchorItem    // the bar item it hangs under
    property string screenName: ""       // the bar's monitor
    property string icon: ""
    property string title: ""
    property string status: ""           // one line under the heading (what is going on right now)
    property color statusTint: theme.muted
    property int panelWidth: theme.px(400)
    property string hotkeySetting: ""    // the setting with this panel's hotkey (for the menu and the cheatsheet)
    property string en: title            // the name in the menu's «Panels» level
    property string nb: title
    default property alias content: body.data
    signal opened

    Component.onCompleted: Panels.register(name, { icon: icon, en: en, nb: nb, setting: hotkeySetting })

    readonly property bool wanted: Panels.current === name && Panels.screen === screenName && anchorItem.visible
    onWantedChanged: { visible = wanted; if (wanted) { Qt.callLater(focusFirst); opened(); } }
    // closed from outside (a click elsewhere: the compositor ends the popup)
    onVisibleChanged: if (!visible && wanted) Panels.close(name)
    // Keyboard focus, and a click anywhere else closes it. Hyprland's focus grab, not an xdg popup grab: that one
    // needs a fresh click, so a panel opened by a hotkey, the menu or IPC would close at once.
    HyprlandFocusGrab {
        windows: [dd]
        active: dd.visible
        onCleared: Panels.close(dd.name)
    }

    anchor.item: anchorItem
    anchor.rect.x: anchorItem.width - implicitWidth   // right edges line up; it slides left/right to stay on screen
    anchor.rect.y: anchorItem.height
    implicitWidth: panelWidth
    implicitHeight: frame.height
    color: "transparent"

    property Item initialFocus: null     // where the keyboard starts (else the first action)
    function focusFirst() {
        if (initialFocus && initialFocus.visible) { initialFocus.forceActiveFocus(); return; }
        const first = frame.nextItemInFocusChain(true);
        if (first && first !== frame) first.forceActiveFocus(); else frame.forceActiveFocus();
    }
    function moveFocus(forward) {
        const cur = frame.Window.activeFocusItem || frame;
        const next = cur.nextItemInFocusChain(forward);
        if (next) next.forceActiveFocus();
    }

    FocusScope {
        id: frame
        width: dd.panelWidth
        height: column.implicitHeight + 2
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) Panels.close(dd.name);
            else if (e.key === Qt.Key_Down) dd.moveFocus(true);
            else if (e.key === Qt.Key_Up) dd.moveFocus(false);
            else return;
            e.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: dd.theme.surface
            border.color: dd.theme.line
            // the gold corners of the menu: the same family of windows
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: dd.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: dd.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: dd.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: dd.theme.gold }
        }

        Column {
            id: column
            x: 1; y: 1
            width: parent.width - 2
            topPadding: dd.theme.px(14)
            bottomPadding: dd.theme.px(10)
            spacing: dd.theme.px(10)

            // heading: the god's sign (or the panel's icon), the name in spaced capitals, and what is going on
            Column {
                x: dd.theme.px(18)
                width: parent.width - 2 * x
                spacing: dd.theme.px(4)
                Row {
                    spacing: 8
                    Text {
                        visible: dd.icon !== ""
                        text: dd.icon
                        font { family: "Symbols Nerd Font Mono"; pixelSize: dd.theme.px(14) }
                        color: dd.theme.gold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: dd.title.toUpperCase()
                        font { family: dd.theme.mono; pixelSize: dd.theme.px(12); bold: true; letterSpacing: 2 }
                        color: dd.theme.gold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Text {
                    visible: dd.status !== ""
                    width: parent.width
                    text: dd.status
                    wrapMode: Text.Wrap
                    font { family: dd.theme.mono; pixelSize: dd.theme.px(13) }
                    color: dd.statusTint
                }
            }

            Column {
                id: body
                width: parent.width
                spacing: dd.theme.px(2)
            }
        }
    }
}
