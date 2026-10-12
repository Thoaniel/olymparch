// The media keys without playerctl: olymparch-media calls `qs ipc call media playPause` (next, previous, stop),
// and this sends it to the same player the bar shows (the one that plays, else a paused one with a title).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Scope {
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) || ps.find(p => p.trackTitle && p.playbackState === MprisPlaybackState.Paused) || ps[0] || null;
    }
    IpcHandler {
        target: "media"
        function playPause(): void { if (player && player.canTogglePlaying) player.togglePlaying(); }
        function next(): void { if (player && player.canGoNext) player.next(); }
        function previous(): void { if (player && player.canGoPrevious) player.previous(); }
        function stop(): void { if (player && player.canControl) player.stop(); }
        function current(): string { return player ? (player.identity || "") + "\t" + (player.trackTitle || "") : ""; }
    }
}
