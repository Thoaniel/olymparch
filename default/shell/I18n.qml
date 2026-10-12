pragma Singleton
// English by default; Norwegian (bokmål) when LANG starts with nb or no. Strings live in
// /usr/share/olymparch/i18n/<lang>.json; a missing key falls back to the English text given in the code.
//   Text { text: I18n.t("launcher.search", "Search apps …") }
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: i18n
    readonly property string lang: {
        const l = Quickshell.env("LANG") || "";
        return (l.startsWith("nb") || l.startsWith("no") || l.startsWith("nn")) ? "nb" : "en";
    }
    property var dict: ({})

    FileView {
        path: `/usr/share/olymparch/i18n/${i18n.lang}.json`
        blockLoading: true
        onLoaded: {
            try { i18n.dict = JSON.parse(text()); } catch (e) { i18n.dict = {}; }
        }
    }

    function t(key, fallback) {
        const v = dict[key];
        return v !== undefined ? v : (fallback !== undefined ? fallback : key);
    }
}
