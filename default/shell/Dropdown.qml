// A dropdown panel under a bar item (B1): the frame every bar panel uses. At most one is open (Panels.qml holds
// which), on the monitor it was opened from; the bar item, the menu's «Panels» level, a hotkey and
// `qs ipc call panel toggle NAME` all open the same one. A click outside or Esc closes it.
// Calm on purpose: a heading, a status line, a few lines and clear actions (PanelAction) — no boxes in boxes.
// Keyboard like the menu: ↑/↓ (and Tab) move between actions, Enter or Space chooses, Esc closes.
// Built like the menu (Menu.qml): a transparent overlay layer over the bar's monitor that takes the keyboard while
// open and closes on a click outside the panel. (A popup with a focus grab got no keyboard when opened by a hotkey
// or IPC, and a click on the wallpaper did not close it.)
//   Dropdown { name: "zeus"; anchorItem: zeusCell; screenName: modelData.name; theme: root
//              icon: ""; title: "Zeus"; status: "Idle · gemma4"
//              PanelAction { label: "Turn AI off"; onActivated: … } }
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
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
    visible: wanted
    onWantedChanged: if (wanted) { place(); Qt.callLater(focusFirst); opened(); }

    screen: Quickshell.screens.find(s => s.name === dd.screenName) || null
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "olymparch-panel"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // where the panel hangs: right edge under the bar item's right edge, kept on the screen
    property real panelX: 8
    property real panelY: 34
    function place() {
        const p = anchorItem.mapToItem(null, anchorItem.width, anchorItem.height);
        panelX = Math.max(8, Math.min(p.x - panelWidth, width - panelWidth - 8));
        panelY = p.y;
    }
    onWidthChanged: if (visible) place()

    // a click anywhere outside the panel closes it
    MouseArea { anchors.fill: parent; onClicked: Panels.close(dd.name) }

    property Item initialFocus: null     // where the keyboard starts (else the first action)
    function focusFirst() {
        if (initialFocus && initialFocus.visible) { initialFocus.forceActiveFocus(); return; }
        const first = frame.nextItemInFocusChain(true);
        if (first && first !== frame) first.forceActiveFocus(); else frame.forceActiveFocus();
    }
    function moveFocus(forward) {
        const cur = frame.Window.activeFocusItem || frame;
        const next = cur.nextItemInFocusChain(forward);
        if (next) { next.forceActiveFocus(); ensureVisible(next); }
    }
    function ensureVisible(it) {   // keep what has the keyboard in view when the panel scrolls
        if (!it || !scroller.interactive) return;
        const p = it.mapToItem(column, 0, 0);
        if (p.y < scroller.contentY) scroller.contentY = Math.max(0, p.y - 8);
        else if (p.y + it.height > scroller.contentY + scroller.height)
            scroller.contentY = Math.min(scroller.contentHeight - scroller.height, p.y + it.height - scroller.height + 8);
    }

    FocusScope {
        id: frame
        x: dd.panelX
        y: dd.panelY
        width: dd.panelWidth
        // never taller than the screen below the bar: the content scrolls inside (the wheel, or the keyboard's focus)
        height: Math.min(column.implicitHeight + 2, dd.height - dd.panelY - 12)
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) Panels.close(dd.name);
            else if (e.key === Qt.Key_Down) dd.moveFocus(true);
            else if (e.key === Qt.Key_Up) dd.moveFocus(false);
            else return;
            e.accepted = true;
        }
        MouseArea { anchors.fill: parent }   // a click inside the panel never closes it

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

        Flickable {
            id: scroller
            anchors { fill: parent; margins: 1 }
            contentHeight: column.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
        Column {
            id: column
            width: parent.width
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
}
