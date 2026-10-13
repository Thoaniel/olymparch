// The Plan panel (under the clock): the month with today and the days that have something marked, the weather where
// you are (MET Norway / yr.no, when Settings → Appearance has a place), today's and the next days' plan from Zeus
// (Olympus' calendar), a field for a new item in plain words, your reminders, and a timer with one click.
import QtQuick
import Quickshell
import Quickshell.Io

Dropdown {
    id: p
    name: "plan"
    icon: "\uf073"
    title: t("plan.title", "Plan")
    en: "Plan"
    nb: "Plan"
    panelWidth: theme.px(440)
    function t(key, en) { return I18n.t(key, en); }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    status: Qt.locale().toString(clock.date, I18n.lang === "nb" ? "dddd d. MMMM yyyy" : "dddd d MMMM yyyy")
    initialFocus: Zeus.enabled ? add.input : null

    function iso(d) { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); }
    function hm(s) { const m = String(s || "").match(/T(\d\d:\d\d)/); return m ? m[1] : ""; }
    property var month: new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
    property var events: []            // the next two weeks from Olympus: [{ id, title, start, end, all_day }]
    property var reminders: []         // [{ id, when, text }]
    function load() {
        const from = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate());
        const to = new Date(from.getTime() + 14 * 86400000);
        if (Zeus.enabled) Zeus.http("GET", "/api/v1/plan?from=" + iso(from) + "&to=" + iso(to), null, r => {
            if (r.status === 200 && r.json) p.events = (r.json.events || []).slice().sort((a, b) => String(a.start).localeCompare(String(b.start)));
        });
        rem.running = false; rem.running = true;
    }
    onOpened: { result.text = ""; month = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1); load(); }

    // ── the month
    Item {
        width: p.panelWidth - 2
        height: cal.height + p.theme.px(30)
        Row {
            x: p.theme.px(18); width: parent.width - 2 * x
            height: p.theme.px(24)
            Text {
                width: parent.width - prev.width - next.width
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.locale().toString(p.month, "MMMM yyyy")
                font { family: p.theme.mono; pixelSize: p.theme.px(13); bold: true; capitalization: Font.Capitalize }
                color: p.theme.text
            }
            Text { id: prev; text: "‹"; width: p.theme.px(24); horizontalAlignment: Text.AlignHCenter; font { family: p.theme.mono; pixelSize: p.theme.px(16) } color: pm.containsMouse ? p.theme.goldHi : p.theme.muted
                   MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.month = new Date(p.month.getFullYear(), p.month.getMonth() - 1, 1) } }
            Text { id: next; text: "›"; width: p.theme.px(24); horizontalAlignment: Text.AlignHCenter; font { family: p.theme.mono; pixelSize: p.theme.px(16) } color: nm.containsMouse ? p.theme.goldHi : p.theme.muted
                   MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.month = new Date(p.month.getFullYear(), p.month.getMonth() + 1, 1) } }
        }
        Grid {
            id: cal
            x: p.theme.px(18); y: p.theme.px(28)
            columns: 7
            readonly property real cell: (p.panelWidth - 2 - 2 * p.theme.px(18)) / 7
            readonly property int lead: (p.month.getDay() + 6) % 7     // Monday first
            readonly property int days: new Date(p.month.getFullYear(), p.month.getMonth() + 1, 0).getDate()
            readonly property var marked: p.events.reduce((m, e) => { m[String(e.start).slice(0, 10)] = true; return m; }, {})
            Repeater {
                model: 7
                delegate: Text { required property int index; width: cal.cell; horizontalAlignment: Text.AlignHCenter
                                 text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2)
                                 font { family: p.theme.mono; pixelSize: p.theme.px(11) } color: p.theme.muted }
            }
            Repeater {
                model: cal.lead + cal.days
                delegate: Item {
                    required property int index
                    readonly property int day: index - cal.lead + 1
                    readonly property string key: p.iso(new Date(p.month.getFullYear(), p.month.getMonth(), day))
                    readonly property bool today: key === p.iso(clock.date)
                    width: cal.cell; height: p.theme.px(24)
                    Rectangle { anchors.centerIn: parent; width: p.theme.px(24); height: width; visible: parent.today; color: p.theme.gold }
                    Text {
                        anchors.centerIn: parent
                        visible: parent.day > 0
                        text: parent.day
                        font { family: p.theme.mono; pixelSize: p.theme.px(12); bold: parent.today }
                        color: parent.today ? p.theme.onAccent : p.theme.text
                    }
                    Rectangle { visible: parent.day > 0 && !!cal.marked[parent.key] && !parent.today; width: 4; height: 4
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom } color: p.theme.goldHi }
                }
            }
        }
    }

    // ── the weather (Weather: MET Norway / yr.no, shared with the bar)
    readonly property var weather: Weather.now
    readonly property var words: ({ clearsky: t("wx.clear", "clear"), fair: t("wx.fair", "fair"), partlycloudy: t("wx.partly", "partly cloudy"),
                                     cloudy: t("wx.cloudy", "cloudy"), fog: t("wx.fog", "fog"), rain: t("wx.rain", "rain"), lightrain: t("wx.lightrain", "light rain"),
                                     heavyrain: t("wx.heavyrain", "heavy rain"), sleet: t("wx.sleet", "sleet"), snow: t("wx.snow", "snow"),
                                     rainshowers: t("wx.showers", "showers"), lightrainshowers: t("wx.showers", "showers") })
    PanelLine {
        theme: p.theme
        visible: !!p.weather
        label: p.t("plan.weather", "Weather")
        value: p.weather ? p.weather.temp + " °C  ·  " + (p.words[String(p.weather.symbol).replace(/_(day|night|polartwilight)$/, "")] || String(p.weather.symbol).replace(/_.*/, ""))
                           + "  ·  " + p.weather.wind + " m/s" : ""
    }
    PanelLine {
        theme: p.theme
        visible: !!p.weather && p.weather.later.length > 0
        label: ""
        value: p.weather ? p.weather.later.map(l => String(l.hour).padStart(2, "0") + ": " + l.temp + "°").join("   ") : ""
        valueTint: p.theme.muted
    }
    PanelAction {
        theme: p.theme; visible: !Weather.enabled
        icon: "\u{F0590}"
        label: p.t("plan.weather_set", "Choose a place in Settings to see the weather")
        onActivated: { Panels.close("plan"); Quickshell.execDetached(["olymparch-settings", "open", "appearance"]); }
    }

    // ── today and the next days
    PanelLine { theme: p.theme; heading: true; label: p.t("plan.coming", "Coming up") }
    Text {
        visible: !Zeus.enabled || p.events.length === 0
        x: p.theme.px(18); width: p.panelWidth - 2 - 2 * x
        text: Zeus.enabled ? p.t("plan.empty_14", "Nothing in the next two weeks.") : p.t("plan.no_zeus", "The plan lives in Zeus (Olympus), which is not installed.")
        wrapMode: Text.Wrap
        font { family: p.theme.mono; pixelSize: p.theme.px(13) }
        color: p.theme.muted
    }
    Repeater {
        model: p.events.slice(0, 8)
        delegate: PanelLine {
            required property var modelData
            theme: p.theme
            readonly property var d: new Date(String(modelData.start).slice(0, 10) + "T12:00")
            label: (String(modelData.start).slice(0, 10) === p.iso(clock.date) ? p.t("plan.today_short", "today") : Qt.locale().toString(d, "ddd d.")) + "  "
                   + (modelData.all_day ? "" : p.hm(modelData.start))
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
            Zeus.planAdd(t, r => { result.ok = r.ok; result.text = r.ok ? p.t("plan.added", "Added: ") + ((r.result || {}).title || t) : (r.error || p.t("plan.not_added", "Not added")); p.load(); });
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
    PanelAction { theme: p.theme; visible: Zeus.enabled && result.ok && result.text !== ""; icon: "\uf0e2"; label: p.t("plan.undo", "Undo")
                  onActivated: { Zeus.undo(); result.text = ""; p.load(); } }

    // ── reminders and a timer (olymparch-remind: systemd user timers, so they survive the shell)
    PanelLine { theme: p.theme; heading: true; label: p.t("plan.reminders", "Reminders and timer") }
    Process {
        id: rem
        command: ["sh", "-c", "command -v olymparch-remind >/dev/null && olymparch-remind list"]
        stdout: StdioCollector {
            onStreamFinished: p.reminders = text.split("\n").filter(l => l.includes("\t")).map(l => { const f = l.split("\t"); return { id: f[0], when: f[1], text: f.slice(2).join(" ") }; })
        }
    }
    Process { id: remAct; onExited: { rem.running = false; rem.running = true; } }
    Repeater {
        model: p.reminders
        delegate: PanelAction {
            required property var modelData
            theme: p.theme
            icon: "\u{F009A}"
            label: modelData.when + "  " + modelData.text
            hint: p.t("plan.cancel", "cancel")
            onActivated: { if (!/^[A-Za-z0-9_.@-]+$/.test(modelData.id)) return; remAct.command = ["olymparch-remind", "cancel", modelData.id]; remAct.running = true; }
        }
    }
    Row {
        x: p.theme.px(18)
        spacing: p.theme.px(16)
        height: p.theme.px(26)
        Text { anchors.verticalCenter: parent.verticalCenter; text: p.t("plan.timer", "Timer:"); font { family: p.theme.mono; pixelSize: p.theme.px(12) } color: p.theme.muted }
        Repeater {
            model: [5, 10, 25, 60]
            delegate: Text {
                id: tm
                required property int modelData
                anchors.verticalCenter: parent.verticalCenter
                text: modelData + " min"
                activeFocusOnTab: true
                font { family: p.theme.mono; pixelSize: p.theme.px(13); underline: tmm.containsMouse || activeFocus }
                color: tmm.containsMouse || activeFocus ? p.theme.goldHi : p.theme.gold
                function go() { remAct.command = ["olymparch-remind", modelData + "m", p.t("plan.timer_done", "The timer is done") + " (" + modelData + " min)"]; remAct.running = true; }
                Keys.onReturnPressed: go()
                Keys.onSpacePressed: go()
                MouseArea { id: tmm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tm.go() }
            }
        }
    }
    PanelField {
        theme: p.theme
        hint: p.t("plan.remind", "Remind: «10m Break» or «14:30 Call mum»")
        onAccepted: {
            const m = text.trim().match(/^(\d{1,2}:\d{2}|\d+[smhd]?(?:\d+[smh])?)\s+(.{1,200})$/);
            if (!m) { result.ok = false; result.text = p.t("plan.remind_bad", "Write a time first: 10m, 1h30m or 14:30, then the text."); return; }
            remAct.command = ["olymparch-remind", m[1], m[2]];
            remAct.running = true;
            text = "";
        }
    }
}
