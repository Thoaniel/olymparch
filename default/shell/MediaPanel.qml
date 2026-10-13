// The Media panel (B4), under what is playing: the player (MPRIS: any app that plays) with previous / play-pause /
// next, the other players there are, and what the PC plays through Zeus (Olympus) when it does.
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
    panelWidth: theme.px(420)
    function t(key, en) { return I18n.t(key, en); }
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(x => x.isPlaying) || players.find(x => x.trackTitle) || players[0] || null
    status: player ? [player.trackArtist, player.trackTitle].filter(s => s).join(" – ") || player.identity
                   : t("media.nothing", "Nothing is playing")

    PanelLine { theme: p.theme; visible: !!(p.player && p.player.trackAlbum); label: p.t("media.album", "Album"); value: p.player ? p.player.trackAlbum || "" : "" }
    PanelLine { theme: p.theme; visible: !!p.player; label: p.t("media.app", "Playing in"); value: p.player ? p.player.identity || "" : "" }
    PanelAction {
        theme: p.theme; visible: !!(p.player && p.player.canTogglePlaying)
        icon: p.player && p.player.isPlaying ? "\u{F03E4}" : "\u{F040A}"
        label: p.player && p.player.isPlaying ? p.t("media.pause", "Pause") : p.t("media.play", "Play")
        onActivated: p.player.togglePlaying()
    }
    PanelAction { theme: p.theme; visible: !!(p.player && p.player.canGoNext); icon: "\u{F04AD}"; label: p.t("media.next", "Next"); onActivated: p.player.next() }
    PanelAction { theme: p.theme; visible: !!(p.player && p.player.canGoPrevious); icon: "\u{F04AE}"; label: p.t("media.previous", "Previous"); onActivated: p.player.previous() }

    // other players: one line each, a click plays or pauses that one
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
    // Zeus' own player (the PC plays music or film through Olympus)
    PanelLine { theme: p.theme; heading: true; visible: !!Zeus.media; label: p.t("media.zeus", "Through Zeus") }
    PanelLine {
        theme: p.theme; visible: !!Zeus.media
        label: Zeus.media && Zeus.media.playing ? p.t("media.playing", "playing") : p.t("media.paused", "paused")
        value: Zeus.media ? [Zeus.media.artist, Zeus.media.title].filter(s => s).join(" – ") : ""
    }
}
