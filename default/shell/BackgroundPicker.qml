// Super+Ctrl+Space: the backgrounds of the theme in use, as thumbnails along the bottom of the screen. ←/→ (or a
// click) shows one at once behind everything, Enter (or a double click) keeps it, Esc goes back to the one you had.
// Each theme remembers its own (appearance.background@THEME). The same as Settings → Appearance → Background and
// `olymparch-theme background set N`. Other parts of the shell can open it: qs ipc call backgrounds open.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: picker
    required property var theme
    property bool open: false
    property var items: []
    property int cursor: 0
    property int was: 0            // the one in use when the picker opened (Esc goes back to it)
    readonly property int perRow: 6

    GlobalShortcut {
        appid: "olymparch"
        name: "backgrounds"
        description: "Pick a background"
        onPressed: picker.toggle()
    }
    IpcHandler {   // qs ipc call backgrounds open|toggle|next|prev (a menu entry, a script)
        target: "backgrounds"
        function open(): void { if (!picker.open) picker.toggle(); }
        function toggle(): void { picker.toggle(); }
        function next(): void { setter.command = ["olymparch-theme", "background", "next"]; setter.running = true; }
        function prev(): void { setter.command = ["olymparch-theme", "background", "prev"]; setter.running = true; }
    }
    function toggle() { if (open) back(); else { open = true; lister.running = true; } }
    Process {
        id: lister
        command: ["olymparch-theme", "background", "list", "--json"]
        stdout: StdioCollector { id: listed }
        onExited: {
            try { picker.items = JSON.parse(listed.text) || []; } catch (e) { picker.items = []; }
            picker.was = Math.max(0, picker.items.findIndex(b => b.current));
            picker.cursor = picker.was;
        }
    }
    Process {   // keeps a background: settings.json, then theme.json (the shell reads it again before this ends)
        id: setter
        onExited: picker.theme.bgPreview = null
    }
    // try one: the wallpaper shows it at once; nothing is written until Enter
    function show(i) {
        if (!items.length) return;
        cursor = (i + items.length) % items.length;
        theme.bgPreview = cursor === was ? null : items[cursor];
    }
    function keep() {
        const b = items[cursor];
        open = false;
        if (!b || cursor === was) { theme.bgPreview = null; return; }
        setter.command = ["olymparch-theme", "background", "set", b.id];
        setter.running = true;
    }
    function back() { theme.bgPreview = null; open = false; }

    PanelWindow {
        visible: picker.open
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-backgrounds"
        WlrLayershell.keyboardFocus: picker.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: picker.back() }

        Rectangle {
            id: panel
            width: Math.min(parent.width - 48, grid.width + 40)
            height: col.implicitHeight + 36
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 20 }
            color: picker.theme.surface
            border.color: picker.theme.line
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: picker.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: picker.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: picker.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: picker.theme.gold }
            MouseArea { anchors.fill: parent }   // clicks inside don't close it

            Item {
                focus: picker.open
                Keys.onEscapePressed: picker.back()
                Keys.onLeftPressed: picker.show(picker.cursor - 1)
                Keys.onRightPressed: picker.show(picker.cursor + 1)
                Keys.onUpPressed: picker.show(Math.max(0, picker.cursor - picker.perRow))
                Keys.onDownPressed: picker.show(Math.min(picker.items.length - 1, picker.cursor + picker.perRow))
                Keys.onReturnPressed: picker.keep()
                Keys.onEnterPressed: picker.keep()
                Keys.onSpacePressed: picker.keep()
            }

            Column {
                id: col
                x: 20; y: 18
                spacing: 14
                Row {
                    spacing: 10
                    Text {
                        text: picker.theme.glyph
                        font { family: "Symbols Nerd Font Mono"; pixelSize: picker.theme.px(16) }
                        color: picker.theme.gold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: I18n.t("bg.title", "BACKGROUNDS") + " · " + ((I18n.lang === "nb" ? (picker.theme.themeData.name || {}).nb : "") || (picker.theme.themeData.name || {}).en || "").toUpperCase()
                        font { family: picker.theme.mono; pixelSize: picker.theme.px(14); bold: true; letterSpacing: 2 }
                        color: picker.theme.gold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                BackgroundGrid {
                    id: grid
                    theme: picker.theme
                    columns: Math.min(picker.perRow, Math.max(1, picker.items.length))
                    // as wide as fits: up to six side by side, never wider than the screen (minus the frame)
                    thumbW: Math.max(120, Math.min(160, Math.floor((panel.parent.width - 48 - 40 - (columns - 1) * spacing) / columns)))
                    items: picker.items
                    current: (picker.items[picker.was] || {}).id || ""
                    cursor: picker.cursor
                    onPicked: i => { if (i === picker.cursor) picker.keep(); else picker.show(i); }
                }
                Text {
                    width: grid.width
                    text: I18n.t("bg.hint", "←→ try · Enter keep · Esc back · click twice to keep")
                    font { family: picker.theme.mono; pixelSize: picker.theme.px(11) }
                    color: picker.theme.muted
                }
                Text {
                    width: grid.width
                    text: I18n.t("bg.yours", "Your own: put PNG, JPEG or WebP pictures in ~/.config/olymparch/backgrounds/%1/").arg(picker.theme.themeId)
                    wrapMode: Text.Wrap
                    font { family: picker.theme.mono; pixelSize: picker.theme.px(10) }
                    color: picker.theme.dim
                }
            }
        }
    }
}
