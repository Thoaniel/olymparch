// The Plan panel (B4), under the clock: today's plan from Zeus (Olympus' calendar), a field for a new item in
// plain words («Dentist Fri 10:30»), and Undo for the last change. Without Zeus it shows the date only.
import QtQuick
import Quickshell

Dropdown {
    id: p
    name: "plan"
    icon: "\uf073"
    title: t("plan.title", "Plan")
    en: "Plan"
    nb: "Plan"
    panelWidth: theme.px(420)
    function t(key, en) { return I18n.t(key, en); }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    status: Qt.locale().toString(clock.date, I18n.lang === "nb" ? "dddd d. MMMM yyyy" : "dddd d MMMM yyyy")
    initialFocus: Zeus.enabled ? add.input : null

    function hm(iso) { const m = String(iso || "").match(/T(\d\d:\d\d)/); return m ? m[1] : ""; }
    readonly property var today: (Zeus.plan || []).slice().sort((a, b) => String(a.start).localeCompare(String(b.start)))

    PanelLine { theme: p.theme; heading: true; label: p.t("plan.today", "Today") }
    Text {
        visible: !Zeus.enabled || (Zeus.plan !== null && p.today.length === 0)
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        text: Zeus.enabled ? p.t("plan.empty", "Nothing planned today.") : p.t("plan.no_zeus", "The plan lives in Zeus (Olympus), which is not installed.")
        wrapMode: Text.Wrap
        font { family: p.theme.mono; pixelSize: p.theme.px(13) }
        color: p.theme.muted
    }
    Repeater {
        model: p.today
        delegate: PanelLine {
            required property var modelData
            theme: p.theme
            label: modelData.all_day ? p.t("plan.all_day", "all day") : p.hm(modelData.start) + (modelData.end ? "–" + p.hm(modelData.end) : "")
            value: modelData.title || ""
        }
    }
    PanelField {
        id: add
        theme: p.theme
        visible: Zeus.enabled
        hint: p.t("plan.add", "New: «Dentist Fri 10:30» – Enter adds it")
        onAccepted: {
            const t = text.trim();
            if (!t) return;
            text = "";
            Zeus.planAdd(t, r => { result.text = r.ok ? p.t("plan.added", "Added: ") + ((r.result || {}).title || t) : (r.error || p.t("plan.not_added", "Not added")); result.ok = r.ok; });
        }
    }
    Text {
        id: result
        property bool ok: true
        visible: text !== ""
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        wrapMode: Text.Wrap
        font { family: p.theme.mono; pixelSize: p.theme.px(12) }
        color: ok ? p.theme.muted : p.theme.red
    }
    PanelAction {
        theme: p.theme
        visible: Zeus.enabled && result.ok && result.text !== ""
        icon: "\uf0e2"
        label: p.t("plan.undo", "Undo")
        onActivated: { Zeus.undo(); result.text = ""; }
    }
    onOpened: result.text = ""
}
