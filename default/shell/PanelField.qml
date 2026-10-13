// A one-line text field in a Dropdown: the theme's field colour, a gold edge when it has the keyboard, a hint
// while empty; Enter calls accepted(). Used where a panel takes a few words (a plan item, a task, a folder).
//   PanelField { theme: root; hint: "Dentist Fri 10:30"; onAccepted: Zeus.planAdd(text) }
import QtQuick

Item {
    id: f
    required property var theme
    property alias text: input.text
    property alias input: input
    property string hint: ""
    property bool password: false
    signal accepted
    width: parent ? parent.width : 300
    height: theme.px(40)
    Rectangle {
        anchors { fill: parent; leftMargin: f.theme.px(12); rightMargin: f.theme.px(12); topMargin: f.theme.px(4); bottomMargin: f.theme.px(4) }
        color: f.theme.field
        border.color: input.activeFocus ? f.theme.gold : f.theme.line
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            verticalAlignment: TextInput.AlignVCenter
            activeFocusOnTab: true
            echoMode: f.password ? TextInput.Password : TextInput.Normal
            font { family: f.theme.mono; pixelSize: f.theme.px(13) }
            color: f.theme.text
            selectionColor: f.theme.gold
            clip: true
            Keys.onReturnPressed: f.accepted()
            Keys.onEnterPressed: f.accepted()
            Text { visible: !input.text; anchors.verticalCenter: parent.verticalCenter; width: parent.width; elide: Text.ElideRight; text: f.hint; font: input.font; color: f.theme.muted }
        }
    }
}
