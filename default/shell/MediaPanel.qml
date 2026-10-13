// The Media panel (under what is playing): the cover, title and artist, a timeline you can drag (when the player can
// seek), play/pause, next, previous, the player's own volume, the other players, and Zeus' own player.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Dropdown {
    id: p
    name: "media"
    icon: "\u{F075A}"
    title: t("media.title", "Media")
    en: "Media"
    nb: "Media"
    panelWidth: theme.px(440)
    function t(key, en) { return I18n.t(key, en); }
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(x => x.isPlaying) || players.find(x => x.trackTitle) || players[0] || null
    status: player ? (player.identity || "") : t("media.nothing", "Nothing is playing")
    // MPRIS does not push the position while playing: ask once a second while the panel is open
    Timer { running: p.visible && p.player && p.player.isPlaying; interval: 1000; repeat: true; onTriggered: p.player.positionChanged() }
    readonly property bool timed: !!(player && player.lengthSupported && player.positionSupported && player.length > 0)
    function clock(s) { s = Math.max(0, Math.round(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    // the cover and what it is, side by side
    Item {
        visible: !!p.player
        width: p.panelWidth - 2
        height: p.theme.px(96)
        Rectangle {
            id: coverBox
            x: p.theme.px(18); y: 4
            width: p.theme.px(88); height: width
            color: p.theme.raised
            Image {
                anchors.fill: parent
                source: p.player && p.player.trackArtUrl ? p.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize { width: 200; height: 200 }
            }
            Text {
                visible: !(p.player && p.player.trackArtUrl)
                anchors.centerIn: parent
                text: "\u{F075A}"
                font { family: "Symbols Nerd Font Mono"; pixelSize: p.theme.px(28) }
                color: p.theme.muted
            }
        }
        Column {
            anchors { left: coverBox.right; leftMargin: 14; right: parent.right; rightMargin: p.theme.px(18); verticalCenter: coverBox.verticalCenter }
            spacing: 3
            Text { width: parent.width; text: p.player ? p.player.trackTitle || p.t("media.unknown", "Unknown") : ""; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                   font { family: p.theme.mono; pixelSize: p.theme.px(14); bold: true } color: p.theme.text }
            Text { width: parent.width; text: p.player ? p.player.trackArtist || "" : ""; elide: Text.ElideRight
                   font { family: p.theme.mono; pixelSize: p.theme.px(13) } color: p.theme.gold }
            Text { width: parent.width; visible: !!(p.player && p.player.trackAlbum); text: p.player ? p.player.trackAlbum || "" : ""; elide: Text.ElideRight
                   font { family: p.theme.mono; pixelSize: p.theme.px(12) } color: p.theme.muted }
        }
    }
    PanelSlider {
        theme: p.theme
        visible: !!p.player
        label: p.timed ? p.clock(p.player.position) : "--:--"
        value: p.timed ? p.player.position / p.player.length : 0
        valueText: p.timed ? p.clock(p.player.length) : p.t("media.live", "live")
        enabled: p.timed && p.player.canSeek
        onMoved: v => { if (p.player.canSeek) p.player.position = v * p.player.length; }
    }
    PanelAction {
        theme: p.theme; visible: !!p.player; enabledAction: !!(p.player && p.player.canTogglePlaying)
        icon: p.player && p.player.isPlaying ? "\u{F03E4}" : "\u{F040A}"
        label: p.player && p.player.isPlaying ? p.t("media.pause", "Pause") : p.t("media.play", "Play")
        onActivated: p.player.togglePlaying()
    }
    PanelAction { theme: p.theme; visible: !!p.player; enabledAction: !!(p.player && p.player.canGoNext); icon: "\u{F04AD}"; label: p.t("media.next", "Next"); onActivated: p.player.next() }
    PanelAction { theme: p.theme; visible: !!p.player; enabledAction: !!(p.player && p.player.canGoPrevious); icon: "\u{F04AE}"; label: p.t("media.previous", "Previous"); onActivated: p.player.previous() }
    PanelSlider {
        theme: p.theme
        visible: !!(p.player && p.player.volumeSupported)
        label: p.t("media.volume", "Volume")
        value: p.player ? p.player.volume : 0
        onMoved: v => p.player.volume = v
    }

    PanelLine { theme: p.theme; heading: true; visible: p.players.length > 1; label: p.t("media.others", "Other players") }
    Repeater {
        model: p.players.length > 1 ? p.players.filter(x => x !== p.player) : []
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: modelData.isPlaying ? "\u{F03E4}" : "\u{F040A}"
            label: modelData.identity + (modelData.trackTitle ? ": " + modelData.trackTitle : "")
            onActivated: if (modelData.canTogglePlaying) modelData.togglePlaying()
        }
    }
    PanelLine { theme: p.theme; heading: true; visible: !!Zeus.media; label: p.t("media.zeus", "Through Zeus") }
    PanelLine {
        theme: p.theme; visible: !!Zeus.media
        label: Zeus.media && Zeus.media.playing ? p.t("media.playing", "playing") : p.t("media.paused", "paused")
        value: Zeus.media ? [Zeus.media.artist, Zeus.media.title].filter(s => s).join(" – ") : ""
    }
}
