// One action in a Dropdown: a full-width row with an icon, a label and an optional hint on the right, chosen
// with Enter/Space or a click. The current one has the menu's gold edge. danger: red (it removes or stops).
//   PanelAction { theme: root; icon: ""; label: "Turn AI off"; hint: "frees the GPU"; onActivated: … }
import QtQuick

FocusScope {
    id: a
    required property var theme
    property string icon: ""
    property string label: ""
    property string hint: ""
    property bool danger: false
    property bool enabledAction: true
    signal activated
    width: parent ? parent.width : 300
    height: theme.px(30)
    activeFocusOnTab: enabledAction
    Keys.onPressed: e => {
        if (!a.enabledAction) return;
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { a.activated(); e.accepted = true; }
    }
    readonly property bool lit: activeFocus || mouse.containsMouse

    Rectangle { anchors.fill: parent; color: a.lit && a.enabledAction ? a.theme.raised : "transparent" }
    Rectangle { visible: a.lit && a.enabledAction; width: 2; height: parent.height; color: a.danger ? a.theme.red : a.theme.gold }
    Text {
        id: ic
        x: a.theme.px(18); width: a.theme.px(18)
        anchors.verticalCenter: parent.verticalCenter
        text: a.icon
        horizontalAlignment: Text.AlignHCenter
        font { family: "Symbols Nerd Font Mono"; pixelSize: a.theme.px(13) }
        color: !a.enabledAction ? a.theme.line : a.danger ? a.theme.red : a.lit ? a.theme.gold : a.theme.muted
    }
    Text {
        anchors { left: ic.right; leftMargin: 10; right: hintText.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: a.label
        elide: Text.ElideRight
        font { family: a.theme.mono; pixelSize: a.theme.px(14); bold: a.lit && a.enabledAction }
        color: !a.enabledAction ? a.theme.muted : a.danger ? a.theme.red : a.lit ? a.theme.goldHi : a.theme.text
    }
    Text {
        id: hintText
        anchors { right: parent.right; rightMargin: a.theme.px(18); verticalCenter: parent.verticalCenter }
        text: a.hint
        font { family: a.theme.mono; pixelSize: a.theme.px(12) }
        color: a.theme.muted
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: a.enabledAction
        cursorShape: Qt.PointingHandCursor
        onClicked: { a.forceActiveFocus(); a.activated(); }
    }
}
