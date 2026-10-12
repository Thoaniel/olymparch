// Thumbnails of the backgrounds of the theme in use (olymparch-theme background list --json): the temple, the theme's
// scenes and your pictures. Used by the background picker (Super+Ctrl+Space) and by Settings → Appearance → Background.
// The one in use has a ✓ and «in use»; the one under the keyboard (or the pointer) a thick frame with a ring.
import QtQuick

Grid {
    id: grid
    required property var theme
    property var items: []            // [{ index, id, name, kind, thumb, frames, source, current }]
    property string current: ""       // the id in use
    property int cursor: -1           // keyboard focus (-1: none)
    property int thumbW: 192
    readonly property int thumbH: Math.round(thumbW * 9 / 16)
    signal picked(int index)
    signal hovered(int index)
    spacing: 12

    function nameOf(b) { return b ? ((I18n.lang === "nb" ? b.name.nb : "") || b.name.en) : ""; }
    function kindOf(b) {
        if (!b) return "";
        if (b.kind === "image") return b.source === "all" ? I18n.t("bg.picture_all", "your picture · every theme") : I18n.t("bg.picture", "your picture");
        return b.frames > 1 ? I18n.t("bg.live", "live") : I18n.t("bg.still", "still");
    }

    Repeater {
        model: grid.items
        delegate: Column {
            id: card
            required property var modelData
            required property int index
            readonly property bool now: modelData.id === grid.current
            readonly property bool focused: grid.cursor === index
            spacing: 6

            Rectangle {
                width: grid.thumbW; height: grid.thumbH
                color: grid.theme.bg
                border.width: card.focused ? 2 : 1
                border.color: card.focused ? grid.theme.goldHi : card.now ? grid.theme.gold : grid.theme.line
                Image {
                    anchors { fill: parent; margins: card.focused ? 2 : 1 }
                    source: card.modelData.thumb ? "file://" + encodeURI(card.modelData.thumb) : ""
                    sourceSize: Qt.size(grid.thumbW * 2, grid.thumbH * 2)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    cache: true
                }
                Rectangle {   // keyboard focus: a ring outside the frame
                    visible: card.focused
                    anchors { fill: parent; margins: -4 }
                    color: "transparent"
                    border.width: 1
                    border.color: grid.theme.goldHi
                }
                Rectangle {   // the one in use: a ✓ on a small plate, readable on any picture
                    visible: card.now
                    anchors { right: parent.right; top: parent.top; margins: 6 }
                    width: 22; height: 22
                    color: grid.theme.gold
                    Text {
                        anchors.centerIn: parent
                        text: "\u{f012c}"
                        font { family: "Symbols Nerd Font Mono"; pixelSize: grid.theme.px(14) }
                        color: grid.theme.onAccent
                    }
                }
                Text {   // its number, for `olymparch-theme background set N`
                    anchors { left: parent.left; top: parent.top; margins: 6 }
                    text: card.index + 1
                    font { family: grid.theme.mono; pixelSize: grid.theme.px(10); bold: true }
                    color: grid.theme.text
                    Rectangle { anchors { fill: parent; margins: -3 } z: -1; color: grid.theme.surface; opacity: 0.85 }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: grid.hovered(card.index)
                    onClicked: grid.picked(card.index)
                }
            }
            Text {
                width: grid.thumbW
                text: grid.nameOf(card.modelData)
                elide: Text.ElideRight
                font { family: grid.theme.mono; pixelSize: grid.theme.px(12); bold: card.now || card.focused }
                color: card.focused ? grid.theme.goldHi : grid.theme.text
            }
            Text {
                width: grid.thumbW
                text: (card.now ? I18n.t("theme.in_use", "IN USE") + " · " : "") + grid.kindOf(card.modelData)
                elide: Text.ElideRight
                font { family: grid.theme.mono; pixelSize: grid.theme.px(10); letterSpacing: 0.5 }
                color: card.now ? grid.theme.gold : grid.theme.muted
            }
        }
    }
}
