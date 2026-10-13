// A slider row in a Dropdown: a label, a bar you drag or click, the value on the right. ←/→ step it by 5 %
// (PageUp/PageDown by 20 %) when it has the keyboard. value 0…1; moved(v) while you change it.
//   PanelSlider { theme: root; label: "Spotify"; value: node.audio.volume; onMoved: v => node.audio.volume = v }
import QtQuick

FocusScope {
    id: s
    required property var theme
    property string label: ""
    property real value: 0
    property string valueText: Math.round(value * 100) + " %"
    property bool muted: false
    property real maximum: 1
    signal moved(real v)
    width: parent ? parent.width : 300
    height: theme.px(30)
    activeFocusOnTab: true
    function set(v) { s.moved(Math.max(0, Math.min(s.maximum, v))); }
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Left) set(value - 0.05);
        else if (e.key === Qt.Key_Right) set(value + 0.05);
        else if (e.key === Qt.Key_PageDown) set(value - 0.2);
        else if (e.key === Qt.Key_PageUp) set(value + 0.2);
        else return;
        e.accepted = true;
    }
    Rectangle { anchors.fill: parent; visible: s.activeFocus; color: s.theme.raised }
    Rectangle { visible: s.activeFocus; width: 2; height: parent.height; color: s.theme.gold }
    Text {
        id: lab
        x: s.theme.px(18)
        width: s.theme.px(120)
        anchors.verticalCenter: parent.verticalCenter
        text: s.label
        elide: Text.ElideRight
        font { family: s.theme.mono; pixelSize: s.theme.px(13) }
        color: s.muted ? s.theme.muted : s.theme.text
    }
    Item {
        id: track
        anchors { left: lab.right; leftMargin: 10; right: val.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        height: s.theme.px(14)
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; color: s.theme.line }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.min(1, s.value / s.maximum); height: 4
            color: s.muted ? s.theme.muted : s.theme.gold
        }
        Rectangle {   // the handle: a small square, like the shell's switches
            x: Math.max(0, Math.min(parent.width - width, parent.width * Math.min(1, s.value / s.maximum) - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: s.theme.px(10); height: width
            color: s.activeFocus || drag.pressed ? s.theme.goldHi : s.muted ? s.theme.muted : s.theme.gold
        }
        MouseArea {
            id: drag
            anchors { fill: parent; topMargin: -8; bottomMargin: -8 }
            cursorShape: Qt.PointingHandCursor
            function at(x) { s.forceActiveFocus(); s.set(s.maximum * Math.max(0, Math.min(1, x / track.width))); }
            onPressed: m => at(m.x)
            onPositionChanged: m => { if (pressed) at(m.x); }
            onWheel: w => s.set(s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }
    Text {
        id: val
        anchors { right: parent.right; rightMargin: s.theme.px(18); verticalCenter: parent.verticalCenter }
        width: s.theme.px(52)
        horizontalAlignment: Text.AlignRight
        text: s.valueText
        font { family: s.theme.mono; pixelSize: s.theme.px(12) }
        color: s.theme.muted
    }
}
