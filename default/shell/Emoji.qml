// Super+period (olymparch-tool emoji): the emoji picker. Search in English or Norwegian («hjerte», «heart»), arrows
// to move, Enter types the emoji into the window you came from and copies it. The ones you used last come first.
// Data: emoji.tsv next to this file (dev/emoji-data builds it from Unicode and CLDR).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: picker
    required property var theme
    readonly property bool open: Tools.emojiOpen
    property var all: []          // { e, group, en, nb, words }
    property var recent: []       // emoji strings, newest first
    readonly property int cell: 46

    function close() { Tools.emojiOpen = false; }
    FileView {
        id: data
        path: Quickshell.shellDir + "/emoji.tsv"
        onLoaded: picker.all = text().split("\n").filter(l => l.length > 0).map(l => {
            const p = l.split("\t");
            return { e: p[0], group: p[1], en: p[2], nb: p[3], hay: [p[2], p[3], p[4]].join(" ").toLowerCase() };
        })
    }
    FileView {
        id: recentFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/olymparch/emoji-recent.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { const r = JSON.parse(text()); picker.recent = Array.isArray(r) ? r.slice(0, 32) : []; } catch (e) {} }
    }
    readonly property var shown: {
        const q = search.text.toLowerCase().trim();
        if (!q) {
            const byE = {};
            for (const x of all) byE[x.e] = x;
            const first = recent.map(e => byE[e]).filter(x => x);
            return first.concat(all.filter(x => !recent.includes(x.e)));
        }
        const words = q.split(/\s+/);
        const hits = all.filter(x => words.every(w => x.hay.includes(w)));
        // names that start with the search first
        const starts = x => x.en.toLowerCase().startsWith(words[0]) || x.nb.toLowerCase().startsWith(words[0]);
        return hits.filter(starts).concat(hits.filter(x => !starts(x)));
    }
    readonly property var current: shown[grid.currentIndex] || null
    function choose(i) {
        const x = shown[i];
        if (!x) return;
        recent = [x.e].concat(recent.filter(e => e !== x.e)).slice(0, 32);
        recentFile.setText(JSON.stringify(recent));
        close();
        Quickshell.execDetached(["olymparch-tool", "emoji-type", x.e]);
    }
    onOpenChanged: if (open) { search.text = ""; grid.currentIndex = 0; grid.positionViewAtBeginning(); }

    PanelWindow {
        visible: picker.open
        screen: Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "olymparch-emoji"
        WlrLayershell.keyboardFocus: picker.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: picker.close() }

        Rectangle {
            id: panel
            readonly property int cols: 12
            width: cols * picker.cell + 24
            height: 64 + picker.cell * 6 + 12 + footer.height
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.18
            color: picker.theme.surface
            border.color: picker.theme.line
            Rectangle { x: -1; y: -1; width: 14; height: 2; color: picker.theme.gold }
            Rectangle { x: -1; y: -1; width: 2; height: 14; color: picker.theme.gold }
            Rectangle { x: parent.width - 13; y: parent.height - 1; width: 14; height: 2; color: picker.theme.gold }
            Rectangle { x: parent.width - 1; y: parent.height - 13; width: 2; height: 14; color: picker.theme.gold }
            MouseArea { anchors.fill: parent }

            Text {
                id: title
                anchors { right: parent.right; top: parent.top; margins: 14 }
                height: 28
                verticalAlignment: Text.AlignVCenter
                text: I18n.t("emoji.title", "EMOJI")
                font { family: picker.theme.mono; pixelSize: picker.theme.px(11); bold: true; letterSpacing: 1.5 }
                color: picker.theme.gold
            }
            TextInput {
                id: search
                anchors { left: parent.left; right: title.left; top: parent.top; margins: 14 }
                height: 28
                font { family: picker.theme.mono; pixelSize: picker.theme.px(15) }
                color: picker.theme.text
                verticalAlignment: TextInput.AlignVCenter
                focus: picker.open
                onTextChanged: grid.currentIndex = 0
                Keys.onEscapePressed: picker.close()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onReturnPressed: picker.choose(grid.currentIndex)
                Keys.onEnterPressed: picker.choose(grid.currentIndex)
                Text {
                    visible: !search.text
                    text: I18n.t("emoji.search", "Search emoji (English or Norwegian) …")
                    font: search.font
                    color: picker.theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; top: search.bottom; topMargin: 8 } height: 1; color: picker.theme.line }

            GridView {
                id: grid
                anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: footer.top; topMargin: 14; leftMargin: 12; rightMargin: 12; bottomMargin: 4 }
                clip: true
                cellWidth: picker.cell
                cellHeight: picker.cell
                model: picker.shown
                highlightMoveDuration: 0
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    width: picker.cell; height: picker.cell
                    color: current ? picker.theme.raised : "transparent"
                    border.color: current ? picker.theme.gold : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.e
                        font { family: "Noto Color Emoji"; pixelSize: picker.theme.px(26) }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: grid.currentIndex = parent.index
                        onClicked: picker.choose(parent.index)
                    }
                }
                Text {
                    visible: grid.count === 0 && picker.all.length > 0
                    anchors { left: parent.left; top: parent.top; margins: 6 }
                    text: I18n.t("emoji.none", "No emoji matches.")
                    font { family: picker.theme.mono; pixelSize: picker.theme.px(13) }
                    color: picker.theme.muted
                }
            }

            Item {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 40
                Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: picker.theme.line }
                Text {
                    id: name
                    anchors { left: parent.left; leftMargin: 14; right: keysHint.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    text: !picker.current ? "" : (I18n.lang === "nb" && picker.current.nb ? picker.current.nb : picker.current.en)
                        + (search.text === "" && picker.recent.includes(picker.current.e) ? "  · " + I18n.t("emoji.recent", "recent") : "")
                    font { family: picker.theme.mono; pixelSize: picker.theme.px(13) }
                    color: picker.theme.goldHi
                }
                Text {
                    id: keysHint
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: I18n.t("emoji.keys", "Enter type · Esc close")
                    font { family: picker.theme.mono; pixelSize: picker.theme.px(11) }
                    color: picker.theme.muted
                }
            }
        }
    }
}
