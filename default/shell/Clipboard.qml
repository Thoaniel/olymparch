// Super+Ctrl+V (olymparch-tool clipboard): the clipboard history (cliphist). Type to search, arrows to choose,
// Enter pastes into the window you came from, Delete removes the entry, Ctrl+Delete (or «Clear history») empties
// it. Images show as thumbnails. Settings → Privacy turns the history off (and wipes it) and sets how much is kept.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: cb
    required property var theme
    readonly property bool open: Tools.clipboardOpen
    readonly property bool enabled: Settings.get("privacy.clipboard_history") !== false
    property var entries: []      // { id, kind: "text" | "image", data }
    property bool loading: false
    property bool confirmClear: false

    function close() { Tools.clipboardOpen = false; }
    function reload() { loading = true; lister.running = false; lister.running = true; }
    Process {
        id: lister
        command: ["olymparch-tool", "clip-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                cb.entries = text.split("\n").filter(l => l.length > 0).map(l => {
                    const p = l.split("\t");
                    return { id: p[0], kind: p[1], data: p.slice(2).join("\t") };
                });
                cb.loading = false;
            }
        }
    }
    readonly property var shown: {
        const q = search.text.toLowerCase();
        if (!q) return entries;
        return entries.filter(e => e.kind === "text" ? e.data.toLowerCase().includes(q) : "image bilde".includes(q));
    }
    function paste(i) {
        const e = shown[i];
        if (!e) return;
        close();
        Quickshell.execDetached(["olymparch-tool", "clip-paste", e.id]);
    }
    function remove(i) {
        const e = shown[i];
        if (!e) return;
        entries = entries.filter(x => x.id !== e.id);
        Quickshell.execDetached(["olymparch-tool", "clip-delete", e.id]);
    }
    function clearAll() {
        if (!confirmClear) { confirmClear = true; return; }
        confirmClear = false;
        entries = [];
        Quickshell.execDetached(["olymparch-tool", "clip-wipe"]);
    }
    onOpenChanged: if (open) { search.text = ""; confirmClear = false; list.currentIndex = 0; reload(); }

    PanelWindow {
        visible: cb.open
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-clipboard"
        WlrLayershell.keyboardFocus: cb.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: cb.close() }

        Rectangle {
            id: panel
            width: 600
            height: Math.min(parent.height * 0.6, 64 + Math.max(list.contentHeight, 72) + footer.height)
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.18
            color: cb.theme.surface
            border.color: cb.theme.line
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: cb.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: cb.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: cb.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: cb.theme.gold }
            MouseArea { anchors.fill: parent }

            Text {
                id: title
                anchors { right: parent.right; top: parent.top; margins: 14 }
                height: 28
                verticalAlignment: Text.AlignVCenter
                text: I18n.t("clipboard.title", "CLIPBOARD")
                font { family: cb.theme.mono; pixelSize: cb.theme.px(11); bold: true; letterSpacing: 1.5 }
                color: cb.theme.gold
            }
            TextInput {
                id: search
                anchors { left: parent.left; right: title.left; top: parent.top; margins: 14 }
                height: 28
                font { family: cb.theme.mono; pixelSize: cb.theme.px(15) }
                color: cb.theme.text
                verticalAlignment: TextInput.AlignVCenter
                focus: cb.open
                onTextChanged: { list.currentIndex = 0; cb.confirmClear = false; }
                Keys.onEscapePressed: cb.close()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onReturnPressed: cb.paste(list.currentIndex)
                Keys.onEnterPressed: cb.paste(list.currentIndex)
                Keys.onDeletePressed: event => {
                    if (event.modifiers & Qt.ControlModifier) cb.clearAll();
                    else cb.remove(list.currentIndex);
                }
                Text {
                    visible: !search.text
                    text: I18n.t("clipboard.search", "Search copied text …")
                    font: search.font
                    color: cb.theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; top: search.bottom; topMargin: 8 } height: 1; color: cb.theme.line }

            ListView {
                id: list
                anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: footer.top; topMargin: 12; margins: 6 }
                clip: true
                model: cb.shown
                highlightMoveDuration: 0
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    width: list.width
                    height: modelData.kind === "image" ? 76 : 30
                    color: current ? cb.theme.raised : "transparent"
                    Rectangle { visible: parent.current; width: 2; height: parent.height; color: cb.theme.gold }
                    Text {
                        visible: parent.modelData.kind === "text"
                        anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: parent.modelData.kind === "text" ? parent.modelData.data.replace(/\s+/g, " ") : ""
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font { family: cb.theme.mono; pixelSize: cb.theme.px(14) }
                        color: parent.current ? cb.theme.goldHi : cb.theme.text
                    }
                    Row {
                        visible: parent.modelData.kind === "image"
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 12
                        Rectangle {
                            width: thumb.paintedWidth + 2; height: thumb.paintedHeight + 2
                            color: "transparent"
                            border.color: parent.parent.current ? cb.theme.gold : cb.theme.line
                            Image {
                                id: thumb
                                x: 1; y: 1
                                width: 120; height: 64
                                fillMode: Image.PreserveAspectFit
                                horizontalAlignment: Image.AlignLeft
                                source: parent.parent.parent.modelData.kind === "image" ? "file://" + parent.parent.parent.modelData.data : ""
                                sourceSize { width: 240; height: 128 }
                                asynchronous: true
                                cache: false
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("clipboard.image", "Image")
                            font { family: cb.theme.mono; pixelSize: cb.theme.px(13) }
                            color: parent.parent.current ? cb.theme.goldHi : cb.theme.muted
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = parent.index
                        onClicked: cb.paste(parent.index)
                    }
                }
                Text {   // empty: say why
                    visible: list.count === 0 && !cb.loading
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 18 }
                    wrapMode: Text.Wrap
                    text: !cb.enabled ? I18n.t("clipboard.off", "Clipboard history is off. Turn it on in Settings → Privacy.")
                        : search.text ? I18n.t("clipboard.no_match", "Nothing matches.")
                        : I18n.t("clipboard.empty", "Nothing copied yet. What you copy shows up here.")
                    font { family: cb.theme.mono; pixelSize: cb.theme.px(13) }
                    color: cb.theme.muted
                }
            }

            Item {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 40
                Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: cb.theme.line }
                Text {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: I18n.t("clipboard.keys", "Enter paste · Del remove · Esc close")
                    font { family: cb.theme.mono; pixelSize: cb.theme.px(11) }
                    color: cb.theme.muted
                }
                Rectangle {
                    id: clearButton
                    visible: cb.entries.length > 0
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    width: clearLabel.implicitWidth + 20; height: 26
                    color: cb.confirmClear ? cb.theme.red : clearHover.containsMouse ? cb.theme.raised : "transparent"
                    border.color: cb.confirmClear ? cb.theme.red : cb.theme.line
                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: cb.confirmClear ? I18n.t("clipboard.clear_confirm", "Clear all? Again to confirm")
                            : I18n.t("clipboard.clear", "Clear history") + "  Ctrl+Del"
                        font { family: cb.theme.mono; pixelSize: cb.theme.px(11); bold: cb.confirmClear }
                        color: cb.confirmClear ? cb.theme.bg : clearHover.containsMouse ? cb.theme.goldHi : cb.theme.text
                    }
                    MouseArea { id: clearHover; anchors.fill: parent; hoverEnabled: true; onClicked: cb.clearAll() }
                }
            }
        }
    }
}
