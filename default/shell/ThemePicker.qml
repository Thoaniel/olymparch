// Super+Ctrl+Shift+Space: the gods of Olympus. A grid of themes, each card in its own colours; arrows move,
// Enter or a click uses the theme at once (everything restyles while the picker stays open), Esc closes.
// The same as Settings → Appearance → Theme and `olymparch-theme set ID`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: picker
    required property var theme
    property bool open: false
    property var themes: []
    property int cursor: 0
    readonly property int columns: 4

    GlobalShortcut {
        appid: "olymparch"
        name: "themes"
        description: "Pick a theme"
        onPressed: picker.open = !picker.open
    }
    IpcHandler {   // qs ipc call themes toggle
        target: "themes"
        function toggle(): void { picker.open = !picker.open; }
    }
    Process {
        id: lister
        command: ["olymparch-theme", "list", "--json"]
        stdout: StdioCollector { id: listed }
        onExited: {
            try { picker.themes = JSON.parse(listed.text) || []; } catch (e) { picker.themes = []; }
            const i = picker.themes.findIndex(t => t.id === picker.theme.themeId);
            picker.cursor = Math.max(0, i);
        }
    }
    onOpenChanged: if (open) lister.running = true
    function use(i) {
        const t = themes[i];
        if (t && t.id !== theme.themeId) Settings.set("appearance.theme", t.id);
    }
    function move(d) { if (themes.length) cursor = Math.max(0, Math.min(themes.length - 1, cursor + d)); }

    PanelWindow {
        visible: picker.open
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-themes"
        WlrLayershell.keyboardFocus: picker.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: picker.open = false }

        Rectangle {
            id: panel
            width: grid.width + 40
            height: col.implicitHeight + 36
            anchors.centerIn: parent
            color: picker.theme.surface
            border.color: picker.theme.line
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: picker.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: picker.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: picker.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: picker.theme.gold }
            MouseArea { anchors.fill: parent }   // clicks inside don't close it

            Item {
                focus: picker.open
                Keys.onEscapePressed: picker.open = false
                Keys.onLeftPressed: picker.move(-1)
                Keys.onRightPressed: picker.move(1)
                Keys.onUpPressed: picker.move(-picker.columns)
                Keys.onDownPressed: picker.move(picker.columns)
                Keys.onReturnPressed: picker.use(picker.cursor)
                Keys.onEnterPressed: picker.use(picker.cursor)
                Keys.onSpacePressed: picker.use(picker.cursor)
            }

            Column {
                id: col
                x: 20; y: 18
                spacing: 12
                Row {
                    spacing: 10
                    Text {
                        text: picker.theme.glyph
                        font { family: "Symbols Nerd Font Mono"; pixelSize: picker.theme.px(16) }
                        color: picker.theme.gold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: I18n.t("theme.title", "THE GODS OF OLYMPUS")
                        font { family: picker.theme.mono; pixelSize: picker.theme.px(14); bold: true; letterSpacing: 2 }
                        color: picker.theme.gold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                ThemeGrid {
                    id: grid
                    theme: picker.theme
                    columns: picker.columns
                    themes: picker.themes
                    current: picker.theme.themeId
                    cursor: picker.cursor
                    onHovered: i => picker.cursor = i
                    onPicked: id => { picker.cursor = picker.themes.findIndex(t => t.id === id); picker.use(picker.cursor); }
                }
                Text {   // what the theme in focus is about
                    width: grid.width
                    readonly property var t: picker.themes[picker.cursor]
                    text: t ? ((I18n.lang === "nb" ? t.description.nb : "") || t.description.en) : ""
                    wrapMode: Text.Wrap
                    font { family: picker.theme.mono; pixelSize: picker.theme.px(12) }
                    color: picker.theme.text
                }
                Text {
                    text: I18n.t("theme.hint", "←↑↓→ choose · Enter use · Esc close · Settings → Appearance")
                    font { family: picker.theme.mono; pixelSize: picker.theme.px(11) }
                    color: picker.theme.muted
                }
            }
        }
    }
}
