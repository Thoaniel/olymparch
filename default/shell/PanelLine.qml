// A line of information in a Dropdown: a quiet label on the left and its value on the right (or a sentence
// across the width when there is no value). heading: a small spaced-capitals divider between groups.
//   PanelLine { theme: root; label: "Model"; value: "gemma4 · local" }
//   PanelLine { theme: root; heading: true; label: "Waiting for you" }
import QtQuick

Item {
    id: l
    required property var theme
    property string label: ""
    property string value: ""
    property color valueTint: theme.text
    property bool heading: false
    property bool sub: false              // a quiet group label under a heading (not capitals)
    width: parent ? parent.width : 300
    height: heading ? theme.px(28) : sub ? theme.px(24) : Math.max(theme.px(24), (value ? valueText.implicitHeight : labelText.implicitHeight) + 4)

    Text {
        id: labelText
        x: l.theme.px(18)
        width: l.value ? Math.min(implicitWidth, parent.width * 0.4) : parent.width - 2 * x
        anchors { bottom: l.heading || l.sub ? parent.bottom : undefined; verticalCenter: l.heading || l.sub ? undefined : parent.verticalCenter }
        bottomPadding: l.heading || l.sub ? 4 : 0
        text: l.heading ? l.label.toUpperCase() : l.label
        wrapMode: l.value ? Text.NoWrap : Text.Wrap
        elide: l.value ? Text.ElideRight : Text.ElideNone
        font { family: l.theme.mono; pixelSize: l.theme.px(l.heading ? 11 : l.sub ? 12 : 13); letterSpacing: l.heading ? 1.5 : 0 }
        color: l.theme.muted
    }
    Text {
        id: valueText
        visible: l.value !== ""
        anchors { left: labelText.right; leftMargin: 12; right: parent.right; rightMargin: l.theme.px(18); verticalCenter: parent.verticalCenter }
        horizontalAlignment: Text.AlignRight
        text: l.value
        elide: Text.ElideLeft
        font { family: l.theme.mono; pixelSize: l.theme.px(13) }
        color: l.valueTint
    }
}
