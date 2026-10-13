// The System panel (B4): how the PC is doing at a glance — the health check (olymparch-doctor), updates waiting,
// free space on /, the CPU and GPU temperature — with Check / Update / Roll back / Settings. Read when it opens;
// nothing polls in the background. Data: olymparch-sysinfo --json.
import QtQuick
import Quickshell
import Quickshell.Io

Dropdown {
    id: p
    name: "system"
    icon: ""
    title: t("system.title", "System")
    en: "System"
    nb: "System"
    panelWidth: theme.px(420)
    function t(key, en) { return I18n.t(key, en); }
    property var info: ({})
    property bool loading: false
    status: loading ? t("system.checking", "Checking …")
          : info.problems === undefined ? ""
          : info.problems === 0 ? t("system.ok", "Everything looks fine")
          : t("system.problems", "%1 problem(s) found").replace("%1", info.problems)
    statusTint: info.problems > 0 ? theme.red : theme.muted
    onOpened: { loading = true; probe.running = false; probe.running = true; }

    Process {
        id: probe
        command: ["olymparch-sysinfo", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { p.loading = false; try { p.info = JSON.parse(text.trim()) || {}; } catch (e) { p.info = {}; } }
        }
        onExited: code => { if (code !== 0) p.loading = false; }
    }
    PanelLine { theme: p.theme; visible: p.info.updates !== undefined && p.info.updates !== null; label: p.t("system.updates", "Updates"); value: p.info.updates > 0 ? String(p.info.updates) : p.t("system.none", "none") }
    PanelLine {
        theme: p.theme; visible: p.info.free_gb !== undefined
        label: p.t("system.disk", "Free on /"); value: p.info.free_gb + " GB  (" + p.info.free_pct + " %)"
        valueTint: p.info.free_gb < 10 ? p.theme.red : p.theme.text
    }
    PanelLine { theme: p.theme; visible: p.info.cpu > 0; label: p.t("system.cpu", "CPU"); value: p.info.cpu + " °C"; valueTint: p.info.cpu >= 90 ? p.theme.red : p.theme.text }
    PanelLine { theme: p.theme; visible: p.info.gpu > 0; label: p.t("system.gpu", "Graphics card"); value: p.info.gpu + " °C"; valueTint: p.info.gpu >= 95 ? p.theme.red : p.theme.text }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.doctor", "Check the system"); hint: "olymparch-doctor"; onActivated: { Panels.close("system"); Quickshell.execDetached(["foot", "-H", "olymparch-doctor"]); } }
    PanelAction { theme: p.theme; visible: p.info.updates > 0; icon: ""; label: p.t("system.update", "Update now"); onActivated: { Panels.close("system"); Quickshell.execDetached(["foot", "-H", "olymparch", "update"]); } }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.rollback", "Roll back to a snapshot"); onActivated: { Panels.close("system"); Quickshell.execDetached(["foot", "-e", "olymparch-rollback"]); } }
    PanelAction { theme: p.theme; icon: ""; label: p.t("system.settings", "All settings"); onActivated: { Panels.close("system"); Quickshell.execDetached(["olymparch-settings", "open"]); } }
}
