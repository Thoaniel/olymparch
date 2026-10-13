pragma Singleton
// The weather where you are, for the bar and the Plan panel: MET Norway's locationforecast (yr.no), for the place in
// Settings → Appearance («lat, lon»; empty = no weather, nothing is fetched). Read at start and every 30 minutes,
// with a User-Agent that says who asks, as MET Norway wants.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: w
    readonly property string place: String(Settings.get("appearance.weather_place") || "").trim()
    readonly property bool enabled: /^-?\d{1,2}(\.\d+)?\s*,\s*-?\d{1,3}(\.\d+)?$/.test(place)
    property var now: null              // { temp, wind, symbol, later: [{ hour, temp }], at }
    // a reading older than two hours (offline since) is not shown as the weather now
    Timer { running: !!w.now; interval: 10 * 60 * 1000; repeat: true; onTriggered: if (w.now && Date.now() - w.now.at > 2 * 3600 * 1000) w.now = null }
    onPlaceChanged: refresh()
    function refresh() {
        if (!enabled) { now = null; return; }
        const m = place.split(",").map(x => Number(x.trim()).toFixed(2));
        fetch.command = ["curl", "-fsS", "--max-time", "8", "-A", "Olymparch/1.0 github.com/Thoaniel/olymparch",
                         "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=" + m[0] + "&lon=" + m[1]];
        fetch.running = false; fetch.running = true;
    }
    Timer { running: w.enabled; interval: 30 * 60 * 1000; repeat: true; triggeredOnStart: true; onTriggered: w.refresh() }
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ts = JSON.parse(text).properties.timeseries;
                    const d = t0 => t0.data.instant.details;
                    const sym = t0 => ((t0.data.next_1_hours || t0.data.next_6_hours || {}).summary || {}).symbol_code || "";
                    w.now = { at: Date.now(), temp: Math.round(d(ts[0]).air_temperature), wind: Math.round(d(ts[0]).wind_speed), symbol: sym(ts[0]),
                              later: [3, 6, 9, 12].filter(i => ts[i]).map(i => ({ hour: new Date(ts[i].time).getHours(), temp: Math.round(d(ts[i]).air_temperature) })) };
                } catch (e) { /* keep the last reading */ }
            }
        }
    }
    // the symbol without its time of day: clearsky_day → clearsky
    readonly property string kind: now ? String(now.symbol).replace(/_(day|night|polartwilight)$/, "") : ""
    readonly property bool night: now ? /_night$/.test(now.symbol) : false
    // a Nerd Font icon for the bar
    readonly property string icon: {
        const k = kind;
        if (!k) return "\u{F0590}";
        if (/thunder/.test(k)) return "\u{F0593}";
        if (/snow/.test(k)) return "\u{F0598}";
        if (/sleet/.test(k)) return "\u{F067F}";
        if (/rain/.test(k)) return "\u{F0597}";
        if (k === "fog") return "\u{F0591}";
        if (k === "cloudy") return "\u{F0590}";
        if (k === "partlycloudy" || k === "fair") return night ? "\u{F0F31}" : "\u{F0595}";
        return night ? "\u{F0594}" : "\u{F0599}";
    }
}
