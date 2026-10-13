pragma Singleton
// The last notifications, for the bell's panel: kept in memory only (never written to disk), the newest first, at
// most 30. Those that do-not-disturb or a muted app held back are kept too, marked, so nothing is lost silently.
import QtQuick
import Quickshell

Singleton {
    id: h
    property var items: []        // [{ app, summary, body, time, critical, held }]
    property int unseen: 0        // since the panel was last opened
    function add(n, held) {
        const item = { app: String(n.appName || ""), summary: String(n.summary || ""), body: String(n.body || "").replace(/<[^>]*>/g, ""),
                       time: new Date(), critical: n.urgency === 2, held: held };
        items = [item].concat(items).slice(0, 30);
        unseen += 1;
    }
    function seen() { unseen = 0; }
    function clear() { items = []; unseen = 0; }
}
