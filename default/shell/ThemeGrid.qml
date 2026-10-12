// A grid of theme cards. Each card is drawn in its own theme's colours (its background, the god's name in its text
// colour, the god's sign in its accent and a strip of its palette), so you see the look before you pick it.
// Used by the theme picker (Super+Ctrl+Shift+Space) and by Settings → Appearance → Theme.
import QtQuick

Grid {
    id: grid
    required property var theme       // the shell's theme: the frame around the card in use and the one in focus
    property var themes: []           // olymparch-theme list --json
    property string current: ""       // the id in use
    property int cursor: -1           // keyboard focus (-1: none)
    readonly property int cardW: 176
    readonly property int cardH: 84
    signal picked(string id)
    signal hovered(int index)
    spacing: 10

    function nameOf(t) { return t ? ((I18n.lang === "nb" ? t.name.nb : "") || t.name.en) : ""; }

    Repeater {
        model: grid.themes
        delegate: Rectangle {
            id: card
            required property var modelData
            required property int index
            readonly property var sw: modelData.swatch   // bg, surface, accent, accentHi, text, danger
            readonly property bool now: modelData.id === grid.current
            readonly property bool focused: grid.cursor === index
            width: grid.cardW; height: grid.cardH
            color: sw[0]
            border.width: now || focused ? 2 : 1
            border.color: focused ? grid.theme.goldHi : now ? grid.theme.gold : grid.theme.line

            Text {
                id: sign
                x: 12; y: 10
                text: String.fromCodePoint(parseInt(card.modelData.glyph, 16))
                font { family: "Symbols Nerd Font Mono"; pixelSize: grid.theme.px(20) }
                color: card.sw[2]
            }
            Text {
                anchors { left: sign.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: sign.verticalCenter }
                text: grid.nameOf(card.modelData).toUpperCase()
                elide: Text.ElideRight
                font { family: grid.theme.mono; pixelSize: grid.theme.px(13); bold: true; letterSpacing: 1.5 }
                color: card.sw[4]
            }
            Text {   // the one in use
                visible: card.now
                anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 6 }
                text: "\u{f012c}"
                font { family: "Symbols Nerd Font Mono"; pixelSize: grid.theme.px(14) }
                color: card.sw[3]
            }
            Text {
                x: 12
                anchors { bottom: strip.top; bottomMargin: 6 }
                text: card.modelData.light ? I18n.t("theme.light", "light") : I18n.t("theme.dark", "dark")
                font { family: grid.theme.mono; pixelSize: grid.theme.px(10); letterSpacing: 1 }
                color: card.sw[4]
                opacity: 0.75
            }
            Row {   // the palette: surface, accent, accent emphasised, text, danger
                id: strip
                x: 12; anchors { bottom: parent.bottom; bottomMargin: 10 }
                Repeater {
                    model: [1, 2, 3, 4, 5]
                    Rectangle {
                        required property int modelData
                        width: (grid.cardW - 24) / 5; height: 10
                        color: card.sw[modelData]
                        border.width: modelData === 1 ? 1 : 0
                        border.color: card.sw[4]
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: grid.hovered(card.index)
                onClicked: grid.picked(card.modelData.id)
            }
        }
    }
}
