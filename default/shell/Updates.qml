pragma Singleton
// How many packages can be updated, for the bar. checkupdates (no root) syncs its own copy of the package database
// in your cache 3 minutes after the shell starts and then every 6 hours (not while a game runs); in between the
// count is read offline every 10 minutes, so it drops by itself after you update. Nothing is installed here.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: u
    property int count: 0
    property bool sync: false
    function check(withSync) {
        if (run.running) return;
        u.sync = withSync;
        run.running = true;
    }
    Process {
        id: run
        command: ["sh", "-c",
            "command -v checkupdates >/dev/null || exit 0; " +
            "[ -e \"${XDG_RUNTIME_DIR:-/nonexistent}/olymparch/gaming\" ] && [ \"$1\" = sync ] && exit 0; " +
            "export CHECKUPDATES_DB=\"${XDG_CACHE_HOME:-$HOME/.cache}/olymparch/checkup-db\"; " +
            // offline only once a sync has made the copy: before that pacman would leave an empty local/ that breaks it
            "if [ \"$1\" = sync ]; then checkupdates; elif [ -d \"$CHECKUPDATES_DB/sync\" ]; then checkupdates --nosync; else exit 0; fi 2>/dev/null | grep -c . ; true",
            "sh", u.sync ? "sync" : "nosync"]
        stdout: StdioCollector { onStreamFinished: { const n = parseInt(text.trim()); if (!isNaN(n)) u.count = n; } }
    }
    Timer { running: true; interval: 3 * 60 * 1000; onTriggered: u.check(true) }
    Timer { running: true; interval: 6 * 3600 * 1000; repeat: true; onTriggered: u.check(true) }
    Timer { running: true; interval: 10 * 60 * 1000; repeat: true; triggeredOnStart: true; onTriggered: u.check(false) }
}
